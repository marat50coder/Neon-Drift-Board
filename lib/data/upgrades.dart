import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A permanent board upgrade. Unlike cosmetics these change the simulation:
/// every level adjusts a concrete engine parameter.
class UpgradeDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int maxLevel;
  final int baseCost;
  final int costStep;

  /// How much one level adds, in the unit shown by [format].
  final double perLevel;
  final String unit;

  const UpgradeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.maxLevel,
    required this.baseCost,
    required this.costStep,
    required this.perLevel,
    required this.unit,
  });

  /// Escalating price so late levels are a real investment.
  int costAt(int level) => baseCost + costStep * level;

  double valueAt(int level) => perLevel * level;

  String format(int level) {
    final v = valueAt(level);
    if (unit == '%') return '+${(v * 100).round()}%';
    if (unit == 's') return '+${v.toStringAsFixed(1)}s';
    if (unit == 'hp') return '+${v.round()}';
    return '+${v.toStringAsFixed(2)}';
  }
}

class Upgrades {
  Upgrades._();

  static const List<UpgradeDef> all = [
    UpgradeDef(
      id: 'hull',
      name: 'Hull Plating',
      description: 'Extra hull point so one more impact will not end the run.',
      icon: Icons.favorite_rounded,
      color: AppColors.danger,
      maxLevel: 2,
      baseCost: 1400,
      costStep: 1600,
      perLevel: 1,
      unit: 'hp',
    ),
    UpgradeDef(
      id: 'shield',
      name: 'Shield Module',
      description: 'Start every run with a shield already charged.',
      icon: Icons.shield_rounded,
      color: AppColors.cyan,
      maxLevel: 1,
      baseCost: 2200,
      costStep: 0,
      perLevel: 1,
      unit: 'hp',
    ),
    UpgradeDef(
      id: 'magnet',
      name: 'Magnet Coil',
      description: 'Magnet power-ups last longer on every pickup.',
      icon: Icons.settings_input_antenna_rounded,
      color: AppColors.magenta,
      maxLevel: 5,
      baseCost: 600,
      costStep: 350,
      perLevel: 0.8,
      unit: 's',
    ),
    UpgradeDef(
      id: 'overdrive',
      name: 'Overdrive Core',
      description: 'The overdrive gauge charges faster from skilful play.',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.gold,
      maxLevel: 5,
      baseCost: 800,
      costStep: 450,
      perLevel: 0.10,
      unit: '%',
    ),
    UpgradeDef(
      id: 'turbo',
      name: 'Turbo Cells',
      description: 'Begin each run with a bigger turbo charge in the tank.',
      icon: Icons.bolt_rounded,
      color: AppColors.pink,
      maxLevel: 4,
      baseCost: 500,
      costStep: 300,
      perLevel: 0.12,
      unit: '%',
    ),
    UpgradeDef(
      id: 'handling',
      name: 'Gyro Handling',
      description: 'Snappier lane changes and a more responsive board.',
      icon: Icons.gamepad_rounded,
      color: AppColors.blue,
      maxLevel: 4,
      baseCost: 550,
      costStep: 320,
      perLevel: 0.12,
      unit: '%',
    ),
    UpgradeDef(
      id: 'cargo',
      name: 'Cargo Rack',
      description: 'Spheres and crystals are worth more points.',
      icon: Icons.inventory_2_rounded,
      color: AppColors.purple,
      maxLevel: 5,
      baseCost: 700,
      costStep: 400,
      perLevel: 0.10,
      unit: '%',
    ),
    UpgradeDef(
      id: 'payout',
      name: 'Broker Contacts',
      description: 'Every completed run pays out more credits.',
      icon: Icons.paid_rounded,
      color: AppColors.green,
      maxLevel: 5,
      baseCost: 900,
      costStep: 550,
      perLevel: 0.08,
      unit: '%',
    ),
  ];

  static UpgradeDef byId(String id) =>
      all.firstWhere((u) => u.id == id, orElse: () => all.first);

  static int get maxTotalLevels =>
      all.fold(0, (sum, u) => sum + u.maxLevel);
}

/// Resolved upgrade values handed to the engine at run start.
class UpgradeStats {
  final int bonusHull;
  final bool startShield;
  final double magnetBonusSeconds;
  final double overdriveRate; // multiplier, 1.0 = stock
  final double startTurbo; // absolute 0..1
  final double handling; // multiplier on lane interpolation speed
  final double cargoScore; // multiplier on pickup points
  final double payout; // multiplier on credits

  const UpgradeStats({
    this.bonusHull = 0,
    this.startShield = false,
    this.magnetBonusSeconds = 0,
    this.overdriveRate = 1.0,
    this.startTurbo = 0.35,
    this.handling = 1.0,
    this.cargoScore = 1.0,
    this.payout = 1.0,
  });

  static const stock = UpgradeStats();

  factory UpgradeStats.from(Map<String, int> levels) {
    int lv(String id) => levels[id] ?? 0;
    return UpgradeStats(
      bonusHull: lv('hull'),
      startShield: lv('shield') > 0,
      magnetBonusSeconds: Upgrades.byId('magnet').valueAt(lv('magnet')),
      overdriveRate: 1.0 + Upgrades.byId('overdrive').valueAt(lv('overdrive')),
      startTurbo:
          (0.35 + Upgrades.byId('turbo').valueAt(lv('turbo'))).clamp(0.0, 1.0),
      handling: 1.0 + Upgrades.byId('handling').valueAt(lv('handling')),
      cargoScore: 1.0 + Upgrades.byId('cargo').valueAt(lv('cargo')),
      payout: 1.0 + Upgrades.byId('payout').valueAt(lv('payout')),
    );
  }
}
