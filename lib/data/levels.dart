import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Distinct rule sets. Each mode changes how a run is won, lost and scored —
/// they are not cosmetic variations of the same loop.
enum GameMode {
  /// Story campaign: fixed route length + up to three optional objectives
  /// that award stars.
  campaign,

  /// No finish line. Difficulty escalates forever; the run ends on the last
  /// hull point. Score is the only measure.
  endless,

  /// A countdown instead of a route. Crashing costs seconds, pickups add
  /// them back. Maximise score before the clock dies.
  timeAttack,

  /// A hunter drone chases from behind. Skilful play pushes it back, mistakes
  /// let it close in. Getting caught ends the run instantly.
  pursuit,

  /// No police at all — a flow course of scoring gates. Missing a gate breaks
  /// the chain; the goal is a clean, precise line.
  precision,

  /// Lane grid removed entirely. The board flies freely in two axes with real
  /// momentum, threading gaps in solid walls and flying through bonus rings.
  flight,

  /// A stationary duel against a hunter gunship. Dodge telegraphed attack
  /// patterns, charge your cannon on spheres and shoot it down.
  boss,
}

class GameModeInfo {
  final GameMode mode;
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String rules;
  final IconData icon;
  final Color color;

  const GameModeInfo({
    required this.mode,
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.rules,
    required this.icon,
    required this.color,
  });
}

class Modes {
  Modes._();

  static const campaign = GameModeInfo(
    mode: GameMode.campaign,
    id: 'campaign',
    name: 'Campaign',
    tagline: 'Story routes with objectives',
    description:
        'Work through the city district by district. Every route has a fixed '
        'length and three optional objectives worth one star each.',
    rules: 'Finish the route · 3 objectives · 3 stars',
    icon: Icons.route_rounded,
    color: AppColors.cyan,
  );

  static const endless = GameModeInfo(
    mode: GameMode.endless,
    id: 'endless',
    name: 'Endless',
    tagline: 'How far can you survive?',
    description:
        'There is no finish line. Traffic keeps thickening and the board keeps '
        'accelerating until your last hull point is gone.',
    rules: 'No route limit · rising difficulty · survive',
    icon: Icons.all_inclusive_rounded,
    color: AppColors.magenta,
  );

  static const timeAttack = GameModeInfo(
    mode: GameMode.timeAttack,
    id: 'time_attack',
    name: 'Time Attack',
    tagline: '90 seconds on the clock',
    description:
        'You cannot be destroyed — but every crash burns 5 seconds. Spheres '
        'add a second, crystals add three. Score as high as the clock allows.',
    rules: '90s start · crash −5s · pickups +time',
    icon: Icons.timer_rounded,
    color: AppColors.gold,
  );

  static const pursuit = GameModeInfo(
    mode: GameMode.pursuit,
    id: 'pursuit',
    name: 'Pursuit',
    tagline: 'Outrun the hunter drone',
    description:
        'A hunter locks onto your signal and closes in relentlessly. Grazes, '
        'tricks and turbo push it back — crashes let it swallow you whole.',
    rules: 'Hunter behind you · skill = distance · caught = over',
    icon: Icons.radar_rounded,
    color: AppColors.danger,
  );

  static const precision = GameModeInfo(
    mode: GameMode.precision,
    id: 'precision',
    name: 'Precision',
    tagline: 'A clean line, no police',
    description:
        'No patrols on this course — only scoring gates and barriers. Thread '
        'every gate to keep the chain alive; one miss and the chain resets.',
    rules: 'No police · gate chain · flow scoring',
    icon: Icons.flag_circle_rounded,
    color: AppColors.green,
  );

  static const flight = GameModeInfo(
    mode: GameMode.flight,
    id: 'flight',
    name: 'Free Flight',
    tagline: 'No lanes. Real momentum.',
    description:
        'The lane grid is gone. Drag anywhere to steer the board freely in '
        'both axes — it carries momentum, so you have to fly it, not tap it. '
        'Thread the gaps in solid walls and chain bonus rings.',
    rules: 'Analog 2D steering · gap walls · bonus rings',
    icon: Icons.open_with_rounded,
    color: AppColors.blue,
  );

  static const boss = GameModeInfo(
    mode: GameMode.boss,
    id: 'boss',
    name: 'Gunship Duel',
    tagline: 'A real boss fight',
    description:
        'No route at all — a stand-up fight against an armoured gunship. '
        'Read its telegraphed attacks, dodge freely, collect spheres to charge '
        'your cannon and tap to fire. Three phases, and it gets angrier.',
    rules: 'Free movement · dodge patterns · charge & fire',
    icon: Icons.smart_toy_rounded,
    color: AppColors.danger,
  );

  static const List<GameModeInfo> all = [
    campaign,
    boss,
    flight,
    endless,
    timeAttack,
    pursuit,
    precision,
  ];

  static GameModeInfo info(GameMode m) =>
      all.firstWhere((e) => e.mode == m, orElse: () => campaign);

  static GameModeInfo byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => campaign);
}

// ---------------------------------------------------------------------------
// Campaign
// ---------------------------------------------------------------------------

/// What a level asks of the player beyond simply finishing.
enum ObjectiveType {
  spheres,
  crystals,
  grazes,
  tricks,
  drifts,
  turbos,
  score,
  noCrash,
  combo,
  rings,
  chain,
}

class LevelObjective {
  final ObjectiveType type;
  final int target;
  const LevelObjective(this.type, this.target);

  String get label {
    switch (type) {
      case ObjectiveType.spheres:
        return 'Collect $target spheres';
      case ObjectiveType.crystals:
        return 'Collect $target crystals';
      case ObjectiveType.grazes:
        return 'Graze $target obstacles';
      case ObjectiveType.tricks:
        return 'Land $target air tricks';
      case ObjectiveType.drifts:
        return 'Hold $target long drifts';
      case ObjectiveType.turbos:
        return 'Fire turbo $target times';
      case ObjectiveType.score:
        return 'Score $target points';
      case ObjectiveType.noCrash:
        return 'Finish without crashing';
      case ObjectiveType.combo:
        return 'Reach a x$target combo';
      case ObjectiveType.rings:
        return 'Fly through $target rings';
      case ObjectiveType.chain:
        return 'Build a chain of $target';
    }
  }

  IconData get icon {
    switch (type) {
      case ObjectiveType.spheres:
        return Icons.blur_circular_rounded;
      case ObjectiveType.crystals:
        return Icons.diamond_rounded;
      case ObjectiveType.grazes:
        return Icons.bolt_rounded;
      case ObjectiveType.tricks:
        return Icons.threesixty_rounded;
      case ObjectiveType.drifts:
        return Icons.motion_photos_on_rounded;
      case ObjectiveType.turbos:
        return Icons.rocket_launch_rounded;
      case ObjectiveType.score:
        return Icons.emoji_events_rounded;
      case ObjectiveType.noCrash:
        return Icons.verified_rounded;
      case ObjectiveType.combo:
        return Icons.local_fire_department_rounded;
      case ObjectiveType.rings:
        return Icons.radio_button_unchecked_rounded;
      case ObjectiveType.chain:
        return Icons.link_rounded;
    }
  }
}

class LevelDef {
  final String id;
  final int number;
  final String name;
  final String brief;
  final int districtIndex; // background art, no purchase needed
  final String contractId; // reuses contract speed / payout flavour
  final double targetMeters;
  final int hull; // starting integrity for this level
  final List<LevelObjective> objectives;
  final int reward;

  /// Which rule set this level is played under. The campaign deliberately
  /// rotates between lane running, free flight, duels and the timed variants
  /// so no two acts play the same.
  final GameMode mode;

  const LevelDef({
    required this.id,
    required this.number,
    required this.name,
    required this.brief,
    required this.districtIndex,
    required this.contractId,
    required this.targetMeters,
    required this.hull,
    required this.objectives,
    required this.reward,
    this.mode = GameMode.campaign,
  });

  GameModeInfo get modeInfo => Modes.info(mode);
  bool get isBoss => mode == GameMode.boss;
}

class Campaign {
  Campaign._();

  static const List<LevelDef> levels = [
    // --- Act I: Neon Crossing -----------------------------------------------
    LevelDef(
      id: 'l1',
      number: 1,
      name: 'First Shift',
      brief: 'A short hop across the crossing to test your licence.',
      districtIndex: 0,
      contractId: 'express',
      targetMeters: 500,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.spheres, 10),
        LevelObjective(ObjectiveType.noCrash, 1),
        LevelObjective(ObjectiveType.score, 2800),
      ],
      reward: 180,
    ),
    LevelDef(
      id: 'l2',
      number: 2,
      name: 'Rush Window',
      brief: 'Traffic is picking up. Keep the cargo intact.',
      districtIndex: 0,
      contractId: 'express',
      targetMeters: 650,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.spheres, 16),
        LevelObjective(ObjectiveType.grazes, 4),
        LevelObjective(ObjectiveType.score, 3600),
      ],
      reward: 220,
    ),
    LevelDef(
      id: 'l3',
      number: 3,
      name: 'Air Mail',
      brief: 'Ramps everywhere. Show the dispatchers some style.',
      districtIndex: 0,
      contractId: 'express',
      targetMeters: 750,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.tricks, 2),
        LevelObjective(ObjectiveType.combo, 7),
        LevelObjective(ObjectiveType.score, 4200),
      ],
      reward: 260,
    ),

    // --- Act II: Skyline Arteries -------------------------------------------
    LevelDef(
      id: 'l4',
      number: 4,
      name: 'Off The Grid',
      brief:
          'The overpass has no lane markings. Drop the grid and fly the board '
          'by hand through the gaps.',
      districtIndex: 1,
      contractId: 'express',
      targetMeters: 800,
      hull: 3,
      mode: GameMode.flight,
      objectives: [
        LevelObjective(ObjectiveType.rings, 6),
        LevelObjective(ObjectiveType.spheres, 20),
        LevelObjective(ObjectiveType.noCrash, 1),
      ],
      reward: 320,
    ),
    LevelDef(
      id: 'l5',
      number: 5,
      name: 'Sky Courier',
      brief: 'A longer arterial route with a tight schedule.',
      districtIndex: 1,
      contractId: 'secret',
      targetMeters: 950,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.drifts, 3),
        LevelObjective(ObjectiveType.spheres, 26),
        LevelObjective(ObjectiveType.noCrash, 1),
      ],
      reward: 340,
    ),
    LevelDef(
      id: 'l6',
      number: 6,
      name: 'Enforcer MK-I',
      brief:
          'Dispatch sent a gunship after you. Stand and fight: dodge its '
          'volleys, feed the cannon and bring it down.',
      districtIndex: 1,
      contractId: 'express',
      targetMeters: 0,
      hull: 4,
      mode: GameMode.boss,
      objectives: [
        LevelObjective(ObjectiveType.noCrash, 1),
        LevelObjective(ObjectiveType.spheres, 34),
        LevelObjective(ObjectiveType.score, 10000),
      ],
      reward: 600,
    ),

    // --- Act III: Cloud Terraces --------------------------------------------
    LevelDef(
      id: 'l7',
      number: 7,
      name: 'Terrace Drop',
      brief: 'Sunlit platforms and long open stretches.',
      districtIndex: 2,
      contractId: 'express',
      targetMeters: 950,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.tricks, 4),
        LevelObjective(ObjectiveType.combo, 10),
        LevelObjective(ObjectiveType.score, 5400),
      ],
      reward: 430,
    ),
    LevelDef(
      id: 'l8',
      number: 8,
      name: 'Ninety Seconds',
      brief:
          'The terrace lifts close at dusk. You cannot be destroyed here — but '
          'every impact eats five seconds you do not have.',
      districtIndex: 2,
      contractId: 'secret',
      targetMeters: 0,
      hull: 3,
      mode: GameMode.timeAttack,
      objectives: [
        LevelObjective(ObjectiveType.spheres, 45),
        LevelObjective(ObjectiveType.crystals, 8),
        LevelObjective(ObjectiveType.score, 6000),
      ],
      reward: 500,
    ),
    LevelDef(
      id: 'l9',
      number: 9,
      name: 'Glass Gauntlet',
      brief: 'One crash and the fragile sphere is gone.',
      districtIndex: 2,
      contractId: 'fragile',
      targetMeters: 850,
      hull: 1,
      objectives: [
        LevelObjective(ObjectiveType.score, 5200),
        LevelObjective(ObjectiveType.crystals, 8),
        LevelObjective(ObjectiveType.combo, 11),
      ],
      reward: 560,
    ),

    // --- Act IV: Industrial Grid --------------------------------------------
    LevelDef(
      id: 'l10',
      number: 10,
      name: 'Cargo Yard',
      brief: 'Container canyons packed with barriers.',
      districtIndex: 3,
      contractId: 'overloaded',
      targetMeters: 1050,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.grazes, 16),
        LevelObjective(ObjectiveType.drifts, 5),
        LevelObjective(ObjectiveType.score, 6200),
      ],
      reward: 520,
    ),
    LevelDef(
      id: 'l11',
      number: 11,
      name: 'Foundry Pass',
      brief:
          'The foundry cleared its patrols for the pour. Nothing out here but '
          'gates and hot steel — hold one unbroken line.',
      districtIndex: 3,
      contractId: 'overloaded',
      targetMeters: 1100,
      hull: 3,
      mode: GameMode.precision,
      objectives: [
        LevelObjective(ObjectiveType.chain, 24),
        LevelObjective(ObjectiveType.crystals, 10),
        LevelObjective(ObjectiveType.score, 6800),
      ],
      reward: 580,
    ),
    LevelDef(
      id: 'l12',
      number: 12,
      name: 'Enforcer MK-II',
      brief:
          'They rebuilt it with a sweep beam. Same duel, faster hands — and '
          'only two hull points to make mistakes with.',
      districtIndex: 3,
      contractId: 'storm',
      targetMeters: 0,
      hull: 3,
      mode: GameMode.boss,
      objectives: [
        LevelObjective(ObjectiveType.noCrash, 1),
        LevelObjective(ObjectiveType.spheres, 42),
        LevelObjective(ObjectiveType.score, 13000),
      ],
      reward: 900,
    ),

    // --- Act V: Harbor Circuits ---------------------------------------------
    LevelDef(
      id: 'l13',
      number: 13,
      name: 'Crane Weave',
      brief:
          'Open water under the gantries. No lanes, no floor — thread the '
          'crane arms and hoops at altitude.',
      districtIndex: 4,
      contractId: 'express',
      targetMeters: 1100,
      hull: 3,
      mode: GameMode.flight,
      objectives: [
        LevelObjective(ObjectiveType.rings, 12),
        LevelObjective(ObjectiveType.spheres, 50),
        LevelObjective(ObjectiveType.score, 7000),
      ],
      reward: 640,
    ),
    LevelDef(
      id: 'l14',
      number: 14,
      name: 'Container Maze',
      brief: 'Precision work between stacked freight.',
      districtIndex: 4,
      contractId: 'secret',
      targetMeters: 1200,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.grazes, 22),
        LevelObjective(ObjectiveType.combo, 13),
        LevelObjective(ObjectiveType.crystals, 12),
      ],
      reward: 650,
    ),
    LevelDef(
      id: 'l15',
      number: 15,
      name: 'Tide Runner',
      brief:
          'A harbour drone locked onto your signal at the waterline. Style '
          'buys you distance; every impact hands it back.',
      districtIndex: 4,
      contractId: 'storm',
      targetMeters: 1100,
      hull: 2,
      mode: GameMode.pursuit,
      objectives: [
        LevelObjective(ObjectiveType.score, 7000),
        LevelObjective(ObjectiveType.grazes, 20),
        LevelObjective(ObjectiveType.noCrash, 1),
      ],
      reward: 740,
    ),

    // --- Act VI: Central Spire ----------------------------------------------
    LevelDef(
      id: 'l16',
      number: 16,
      name: 'Corporate Core',
      brief: 'The spire never sleeps and never forgives.',
      districtIndex: 5,
      contractId: 'vip',
      targetMeters: 1250,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.score, 8000),
        LevelObjective(ObjectiveType.crystals, 14),
        LevelObjective(ObjectiveType.tricks, 6),
      ],
      reward: 780,
    ),
    LevelDef(
      id: 'l17',
      number: 17,
      name: 'Executive Cargo',
      brief:
          'A VIP package through a sealed corridor. Patrols are held back, so '
          'the only thing judging you is your own line.',
      districtIndex: 5,
      contractId: 'vip',
      targetMeters: 1300,
      hull: 3,
      mode: GameMode.precision,
      objectives: [
        LevelObjective(ObjectiveType.chain, 34),
        LevelObjective(ObjectiveType.combo, 15),
        LevelObjective(ObjectiveType.noCrash, 1),
      ],
      reward: 860,
    ),
    LevelDef(
      id: 'l18',
      number: 18,
      name: 'Enforcer MK-III',
      brief:
          'The spire launched its best machine. Mine fans, sweep beams and '
          'triple volleys — read all three or die reading two.',
      districtIndex: 5,
      contractId: 'vip',
      targetMeters: 0,
      hull: 3,
      mode: GameMode.boss,
      objectives: [
        LevelObjective(ObjectiveType.noCrash, 1),
        LevelObjective(ObjectiveType.spheres, 50),
        LevelObjective(ObjectiveType.score, 16000),
      ],
      reward: 1300,
    ),

    // --- Act VII: Data Fields -----------------------------------------------
    LevelDef(
      id: 'l19',
      number: 19,
      name: 'Server Canyon',
      brief: 'Cold aisles, hot pursuit.',
      districtIndex: 6,
      contractId: 'secret',
      targetMeters: 1350,
      hull: 3,
      objectives: [
        LevelObjective(ObjectiveType.crystals, 18),
        LevelObjective(ObjectiveType.spheres, 65),
        LevelObjective(ObjectiveType.score, 9000),
      ],
      reward: 900,
    ),
    LevelDef(
      id: 'l20',
      number: 20,
      name: 'Packet Storm',
      brief:
          'The aisles reconfigure mid-run. Solid walls, moving mines, and the '
          'only route is the one you fly.',
      districtIndex: 6,
      contractId: 'storm',
      targetMeters: 1300,
      hull: 2,
      mode: GameMode.flight,
      objectives: [
        LevelObjective(ObjectiveType.rings, 16),
        LevelObjective(ObjectiveType.grazes, 24),
        LevelObjective(ObjectiveType.score, 9000),
      ],
      reward: 1000,
    ),
    LevelDef(
      id: 'l21',
      number: 21,
      name: 'Cold Storage',
      brief:
          'The core ships in ninety seconds or not at all. Impacts burn the '
          'clock, cargo buys it back.',
      districtIndex: 6,
      contractId: 'fragile',
      targetMeters: 0,
      hull: 1,
      mode: GameMode.timeAttack,
      objectives: [
        LevelObjective(ObjectiveType.score, 9500),
        LevelObjective(ObjectiveType.combo, 15),
        LevelObjective(ObjectiveType.crystals, 16),
      ],
      reward: 1100,
    ),

    // --- Act VIII: The Overload ---------------------------------------------
    LevelDef(
      id: 'l22',
      number: 22,
      name: 'Overload Entry',
      brief:
          'They tag you the moment you cross the line. Outrun the hunter all '
          'the way to the district core.',
      districtIndex: 7,
      contractId: 'overloaded',
      targetMeters: 1400,
      hull: 3,
      mode: GameMode.pursuit,
      objectives: [
        LevelObjective(ObjectiveType.score, 10000),
        LevelObjective(ObjectiveType.grazes, 36),
        LevelObjective(ObjectiveType.turbos, 8),
      ],
      reward: 1200,
    ),
    LevelDef(
      id: 'l23',
      number: 23,
      name: 'Signal Break',
      brief: 'No route markers, no mercy, double payout.',
      districtIndex: 7,
      contractId: 'storm',
      targetMeters: 1450,
      hull: 2,
      objectives: [
        LevelObjective(ObjectiveType.score, 10500),
        LevelObjective(ObjectiveType.tricks, 10),
        LevelObjective(ObjectiveType.combo, 17),
      ],
      reward: 1300,
    ),
    LevelDef(
      id: 'l24',
      number: 24,
      name: 'The Overlord',
      brief:
          'One duel. Three hull points. The whole city watching you take the '
          'sky apart.',
      districtIndex: 7,
      contractId: 'vip',
      targetMeters: 0,
      hull: 3,
      mode: GameMode.boss,
      objectives: [
        LevelObjective(ObjectiveType.score, 20000),
        LevelObjective(ObjectiveType.crystals, 10),
        LevelObjective(ObjectiveType.noCrash, 1),
      ],
      reward: 2500,
    ),
  ];

  static LevelDef byId(String id) =>
      levels.firstWhere((l) => l.id == id, orElse: () => levels.first);

  static int get totalStars => levels.length * 3;
}
