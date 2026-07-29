import 'package:flutter/material.dart';

/// A cosmetic / unlockable item backed by a sprite-sheet cell.
class CosmeticItem {
  final String id;
  final String name;
  final int spriteIndex;
  final int price;
  final String rarity; // common | rare | epic | legendary
  final String tagline;

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.spriteIndex,
    required this.price,
    required this.rarity,
    this.tagline = '',
  });
}

class District {
  final String id;
  final String name;
  final int index; // maps to bg sprite
  final int unlockCost;
  final String vibe;
  const District({
    required this.id,
    required this.name,
    required this.index,
    required this.unlockCost,
    required this.vibe,
  });
}

class ContractType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final double speedMul;
  final double rewardMul;
  final int timeSeconds;
  final Color color;
  const ContractType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.speedMul,
    required this.rewardMul,
    required this.timeSeconds,
    required this.color,
  });
}

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int target;
  final String stat; // key in stats map
  final int reward;
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.target,
    required this.stat,
    required this.reward,
  });
}

/// Static content definitions for the whole game.
class Catalog {
  Catalog._();

  static const List<CosmeticItem> boards = [
    CosmeticItem(id: 'board_classic', name: 'Classic Neon', spriteIndex: 0, price: 0, rarity: 'common', tagline: 'Where every drifter begins.'),
    CosmeticItem(id: 'board_carbon', name: 'Carbon Flux', spriteIndex: 1, price: 1200, rarity: 'common', tagline: 'Lightweight woven carbon frame.'),
    CosmeticItem(id: 'board_prism', name: 'Prism Drift', spriteIndex: 2, price: 2600, rarity: 'rare', tagline: 'Refracts the whole spectrum.'),
    CosmeticItem(id: 'board_chrome', name: 'Chrome Phantom', spriteIndex: 3, price: 3200, rarity: 'rare', tagline: 'Liquid metal silhouette.'),
    CosmeticItem(id: 'board_pixel', name: 'Pixel Runner', spriteIndex: 4, price: 4200, rarity: 'epic', tagline: 'Retro-glitch aesthetic.'),
    CosmeticItem(id: 'board_solar', name: 'Solar Edge', spriteIndex: 5, price: 4800, rarity: 'epic', tagline: 'Powered by captured sunlight.'),
    CosmeticItem(id: 'board_crystal', name: 'Crystal Hover', spriteIndex: 6, price: 6000, rarity: 'epic', tagline: 'Carved from pure ice-glass.'),
    CosmeticItem(id: 'board_quantum', name: 'Quantum Board', spriteIndex: 7, price: 7200, rarity: 'legendary', tagline: 'Bends space around you.'),
    CosmeticItem(id: 'board_inferno', name: 'Inferno Glide', spriteIndex: 8, price: 8500, rarity: 'legendary', tagline: 'Molten core, endless burn.'),
    CosmeticItem(id: 'board_aurora', name: 'Aurora Glide', spriteIndex: 9, price: 10000, rarity: 'legendary', tagline: 'Northern lights in motion.'),
  ];

  static const List<CosmeticItem> spheres = [
    CosmeticItem(id: 'sphere_azure', name: 'Azure Sphere', spriteIndex: 0, price: 0, rarity: 'common', tagline: 'Calm oceanic energy.'),
    CosmeticItem(id: 'sphere_crimson', name: 'Crimson Sphere', spriteIndex: 1, price: 900, rarity: 'common', tagline: 'Volatile red plasma.'),
    CosmeticItem(id: 'sphere_emerald', name: 'Emerald Sphere', spriteIndex: 2, price: 1500, rarity: 'rare', tagline: 'Stable green flux.'),
    CosmeticItem(id: 'sphere_violet', name: 'Violet Sphere', spriteIndex: 3, price: 2200, rarity: 'rare', tagline: 'Deep amethyst charge.'),
    CosmeticItem(id: 'sphere_solar', name: 'Solar Sphere', spriteIndex: 4, price: 3000, rarity: 'epic', tagline: 'A captured miniature star.'),
    CosmeticItem(id: 'sphere_prism', name: 'Prism Sphere', spriteIndex: 5, price: 4500, rarity: 'epic', tagline: 'All colors at once.'),
    CosmeticItem(id: 'sphere_quantum', name: 'Quantum Sphere', spriteIndex: 6, price: 6500, rarity: 'legendary', tagline: 'Orbiting probability.'),
    CosmeticItem(id: 'sphere_void', name: 'Void Sphere', spriteIndex: 7, price: 8000, rarity: 'legendary', tagline: 'Contains a tiny singularity.'),
  ];

  static const List<CosmeticItem> trails = [
    CosmeticItem(id: 'trail_ion', name: 'Ion Stream', spriteIndex: 0, price: 0, rarity: 'common'),
    CosmeticItem(id: 'trail_rainbow', name: 'Rainbow Wake', spriteIndex: 1, price: 1000, rarity: 'rare'),
    CosmeticItem(id: 'trail_volt', name: 'Voltline', spriteIndex: 2, price: 1400, rarity: 'rare'),
    CosmeticItem(id: 'trail_bloom', name: 'Pink Bloom', spriteIndex: 3, price: 1600, rarity: 'rare'),
    CosmeticItem(id: 'trail_matrix', name: 'Matrix Rain', spriteIndex: 4, price: 2000, rarity: 'epic'),
    CosmeticItem(id: 'trail_nebula', name: 'Nebula Dust', spriteIndex: 5, price: 2400, rarity: 'epic'),
    CosmeticItem(id: 'trail_solar', name: 'Solar Flare', spriteIndex: 6, price: 2800, rarity: 'epic'),
    CosmeticItem(id: 'trail_glacier', name: 'Glacier Mist', spriteIndex: 7, price: 3200, rarity: 'epic'),
    CosmeticItem(id: 'trail_ember', name: 'Ember Fall', spriteIndex: 8, price: 3800, rarity: 'legendary'),
    CosmeticItem(id: 'trail_prism', name: 'Prism Comet', spriteIndex: 9, price: 4200, rarity: 'legendary'),
  ];

  static const List<CosmeticItem> turbos = [
    CosmeticItem(id: 'turbo_wings', name: 'Ion Wings', spriteIndex: 0, price: 0, rarity: 'common'),
    CosmeticItem(id: 'turbo_phoenix', name: 'Phoenix Burst', spriteIndex: 1, price: 1200, rarity: 'rare'),
    CosmeticItem(id: 'turbo_ring', name: 'Shock Ring', spriteIndex: 2, price: 1600, rarity: 'rare'),
    CosmeticItem(id: 'turbo_pulse', name: 'Pulse Wave', spriteIndex: 3, price: 2000, rarity: 'epic'),
    CosmeticItem(id: 'turbo_aurora', name: 'Aurora Halo', spriteIndex: 4, price: 2600, rarity: 'epic'),
    CosmeticItem(id: 'turbo_solar', name: 'Solar Storm', spriteIndex: 5, price: 3200, rarity: 'epic'),
    CosmeticItem(id: 'turbo_quantum', name: 'Quantum Rush', spriteIndex: 12, price: 4200, rarity: 'legendary'),
    CosmeticItem(id: 'turbo_inferno', name: 'Inferno Trail', spriteIndex: 17, price: 4800, rarity: 'legendary'),
  ];

  static const List<District> districts = [
    District(id: 'd1', name: 'Neon Crossing', index: 0, unlockCost: 0, vibe: 'Downtown intersection maze'),
    District(id: 'd2', name: 'Skyline Arteries', index: 1, unlockCost: 2500, vibe: 'Elevated highway loops'),
    District(id: 'd3', name: 'Cloud Terraces', index: 2, unlockCost: 3500, vibe: 'Sunlit floating platforms'),
    District(id: 'd4', name: 'Industrial Grid', index: 3, unlockCost: 5500, vibe: 'Heavy cargo districts'),
    District(id: 'd5', name: 'Harbor Circuits', index: 4, unlockCost: 7500, vibe: 'Neon docks over water'),
    District(id: 'd6', name: 'Central Spire', index: 5, unlockCost: 10000, vibe: 'The corporate core'),
    District(id: 'd7', name: 'Data Fields', index: 6, unlockCost: 12500, vibe: 'Server-farm canyons'),
    District(id: 'd8', name: 'The Overload', index: 7, unlockCost: 16000, vibe: 'Maximum-danger endgame'),
  ];

  static const List<ContractType> contracts = [
    ContractType(id: 'express', name: 'Express Delivery', description: 'Standard run. Balanced speed and reward.', icon: Icons.local_shipping_rounded, speedMul: 1.0, rewardMul: 1.0, timeSeconds: 0, color: Color(0xFF00E5FF)),
    ContractType(id: 'secret', name: 'Secret Cargo', description: 'Fewer route markers. Higher payout.', icon: Icons.vpn_key_rounded, speedMul: 1.05, rewardMul: 1.3, timeSeconds: 0, color: Color(0xFF9B5CFF)),
    ContractType(id: 'fragile', name: 'Fragile Sphere', description: 'One crash ends the run. Rich bonus.', icon: Icons.diamond_rounded, speedMul: 1.0, rewardMul: 1.6, timeSeconds: 0, color: Color(0xFF2BE38B)),
    ContractType(id: 'overloaded', name: 'Overloaded Route', description: 'More traffic and drones everywhere.', icon: Icons.traffic_rounded, speedMul: 1.1, rewardMul: 1.5, timeSeconds: 0, color: Color(0xFFFFC53D)),
    ContractType(id: 'storm', name: 'Energy Storm', description: 'Blazing speed from the first second.', icon: Icons.bolt_rounded, speedMul: 1.25, rewardMul: 1.8, timeSeconds: 0, color: Color(0xFFFF2FB0)),
    ContractType(id: 'vip', name: 'VIP Delivery', description: 'Long premium contract, elite rewards.', icon: Icons.workspace_premium_rounded, speedMul: 1.15, rewardMul: 2.0, timeSeconds: 0, color: Color(0xFFFF8A3D)),
  ];

  static const List<AchievementDef> achievements = [
    AchievementDef(id: 'a_first', name: 'First Delivery', description: 'Complete your first contract.', icon: Icons.flag_rounded, target: 1, stat: 'deliveries', reward: 300),
    AchievementDef(id: 'a_deliver10', name: 'Courier', description: 'Complete 10 deliveries.', icon: Icons.local_shipping_rounded, target: 10, stat: 'deliveries', reward: 800),
    AchievementDef(id: 'a_deliver50', name: 'Veteran Rider', description: 'Complete 50 deliveries.', icon: Icons.military_tech_rounded, target: 50, stat: 'deliveries', reward: 2500),
    AchievementDef(id: 'a_dist10', name: 'City Sprinter', description: 'Ride 10 km in total.', icon: Icons.route_rounded, target: 10000, stat: 'distance', reward: 600),
    AchievementDef(id: 'a_dist50', name: 'Marathon Drifter', description: 'Ride 50 km in total.', icon: Icons.map_rounded, target: 50000, stat: 'distance', reward: 2000),
    AchievementDef(id: 'a_turbo30', name: 'Turbo Junkie', description: 'Use turbo 30 times.', icon: Icons.bolt_rounded, target: 30, stat: 'turbos', reward: 700),
    AchievementDef(id: 'a_drift50', name: 'Drift King', description: 'Perform 50 long drifts.', icon: Icons.motion_photos_on_rounded, target: 50, stat: 'drifts', reward: 900),
    AchievementDef(id: 'a_spheres100', name: 'Collector', description: 'Collect 100 energy spheres.', icon: Icons.blur_circular_rounded, target: 100, stat: 'spheresCollected', reward: 1000),
    AchievementDef(id: 'a_crystals100', name: 'Crystal Hoarder', description: 'Collect 100 crystals.', icon: Icons.diamond_rounded, target: 100, stat: 'crystalsCollected', reward: 1000),
    AchievementDef(id: 'a_credits10k', name: 'Big Earner', description: 'Earn 12,000 credits total.', icon: Icons.paid_rounded, target: 12000, stat: 'creditsEarned', reward: 1800),
    AchievementDef(id: 'a_gold', name: 'Gold Standard', description: 'Finish a run with a Gold rating.', icon: Icons.workspace_premium_rounded, target: 1, stat: 'goldRuns', reward: 1200),
    AchievementDef(id: 'a_perfect', name: 'Flawless', description: 'Finish a run without crashing.', icon: Icons.verified_rounded, target: 1, stat: 'perfectRuns', reward: 1500),
    AchievementDef(id: 'a_boards5', name: 'Garage Owner', description: 'Own 5 different boards.', icon: Icons.snowboarding_rounded, target: 5, stat: 'boardsOwned', reward: 1800),
    AchievementDef(id: 'a_districts', name: 'Explorer', description: 'Unlock 4 districts.', icon: Icons.travel_explore_rounded, target: 4, stat: 'districtsOwned', reward: 2200),
    AchievementDef(id: 'a_score', name: 'High Scorer', description: 'Reach a single-run score of 12,000.', icon: Icons.emoji_events_rounded, target: 12000, stat: 'bestScore', reward: 3000),
    AchievementDef(id: 'a_streak', name: 'Streak Master', description: 'Reach a x14 combo in one run.', icon: Icons.local_fire_department_rounded, target: 14, stat: 'bestCombo', reward: 2500),
    AchievementDef(id: 'a_campaign5', name: 'Getting Started', description: 'Clear 5 campaign levels.', icon: Icons.map_rounded, target: 5, stat: 'levelsCleared', reward: 800),
    AchievementDef(id: 'a_campaign_all', name: 'City Legend', description: 'Clear all 24 campaign levels.', icon: Icons.stars_rounded, target: 24, stat: 'levelsCleared', reward: 5000),
    AchievementDef(id: 'a_stars30', name: 'Star Collector', description: 'Earn 30 campaign stars.', icon: Icons.star_rounded, target: 30, stat: 'campaignStars', reward: 2000),
    AchievementDef(id: 'a_upgrades10', name: 'Engineer', description: 'Install 10 upgrade levels.', icon: Icons.build_rounded, target: 10, stat: 'upgradesOwned', reward: 2200),
    AchievementDef(id: 'a_graze200', name: 'Close Call', description: 'Graze 200 obstacles in total.', icon: Icons.bolt_rounded, target: 200, stat: 'grazes', reward: 1600),
    AchievementDef(id: 'a_tricks50', name: 'Air Show', description: 'Land 50 air tricks.', icon: Icons.threesixty_rounded, target: 50, stat: 'tricks', reward: 1400),
    AchievementDef(id: 'a_boss1', name: 'Gunship Killer', description: 'Shoot down an Enforcer gunship.', icon: Icons.gps_fixed_rounded, target: 1, stat: 'bossKills', reward: 1500),
    AchievementDef(id: 'a_boss5', name: 'Sky Cleaner', description: 'Win 5 gunship duels.', icon: Icons.smart_toy_rounded, target: 5, stat: 'bossKills', reward: 3500),
    AchievementDef(id: 'a_rings100', name: 'Ring Threader', description: 'Fly through 100 rings.', icon: Icons.radio_button_unchecked_rounded, target: 100, stat: 'rings', reward: 1800),
  ];

  static CosmeticItem boardById(String id) =>
      boards.firstWhere((b) => b.id == id, orElse: () => boards.first);
  static CosmeticItem sphereById(String id) =>
      spheres.firstWhere((b) => b.id == id, orElse: () => spheres.first);
  static CosmeticItem trailById(String id) =>
      trails.firstWhere((b) => b.id == id, orElse: () => trails.first);
  static CosmeticItem turboById(String id) =>
      turbos.firstWhere((b) => b.id == id, orElse: () => turbos.first);
}
