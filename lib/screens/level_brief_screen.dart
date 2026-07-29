import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/levels.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'game_screen.dart';

/// Pre-run briefing: route facts, the three star objectives and the payout.
class LevelBriefScreen extends StatelessWidget {
  final LevelDef level;
  const LevelBriefScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final contract = Catalog.contracts.firstWhere(
        (c) => c.id == level.contractId,
        orElse: () => Catalog.contracts.first);
    final district = Catalog.districts.firstWhere(
        (d) => d.index == level.districtIndex,
        orElse: () => Catalog.districts.first);
    final stars = gs.starsFor(level.id);
    final bg =
        'assets/Neon_Drift_Board_gameplay_assets/bg_location_${level.districtIndex + 1}_asset.webp';

    return Scaffold(
      body: NeonBackground(
        accent: contract.color,
        accent2: AppColors.purple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'Level ${level.number}', accent: contract.color),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _headerCard(bg, district, stars),
                      const SizedBox(height: 12),
                      if (level.mode != GameMode.campaign) ...[
                        _modeCard(),
                        const SizedBox(height: 12),
                      ],
                      _factsCard(contract),
                      const SizedBox(height: 12),
                      _objectivesCard(),
                      const SizedBox(height: 12),
                      _rewardCard(gs),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: NeonButton(
                    label: level.isBoss
                        ? (stars > 0 ? 'Rematch' : 'Engage')
                        : (stars > 0 ? 'Replay Route' : 'Start Route'),
                    icon: level.isBoss
                        ? Icons.gps_fixed_rounded
                        : Icons.play_arrow_rounded,
                    height: 58,
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          contract: contract,
                          mode: level.mode,
                          level: level,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(String bg, District district, int stars) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 172,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bg, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgDeep.withValues(alpha: 0.30),
                    AppColors.bgDeep.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (i) => Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 20,
                        color: i < stars ? AppColors.gold : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(level.name,
                      style: const TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(district.name,
                      style: const TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 12,
                          color: AppColors.textMid)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Special levels play by different rules — spell them out before the run.
  Widget _modeCard() {
    final info = level.modeInfo;
    return GlassCard(
      tint: info.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: info.color.withValues(alpha: 0.16),
                  border: Border.all(color: info.color.withValues(alpha: 0.5)),
                ),
                child: Icon(info.icon, color: info.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name.toUpperCase(),
                        style: TextStyle(
                            fontFamily: AppText.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.4,
                            color: info.color)),
                    Text(info.tagline,
                        style: const TextStyle(
                            fontFamily: AppText.body,
                            fontSize: 11.5,
                            color: AppColors.textMid)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(info.description,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textMid)),
          const SizedBox(height: 8),
          Text(info.rules,
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: info.color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _factsCard(ContractType contract) {
    final routeless = level.targetMeters <= 0;
    return GlassCard(
      tint: contract.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(level.brief,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textMid)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (routeless)
                _fact(level.modeInfo.icon, level.isBoss ? 'Duel' : 'Timed',
                    'FORMAT', level.modeInfo.color)
              else
                _fact(Icons.straighten_rounded,
                    '${level.targetMeters.round()} m', 'ROUTE', AppColors.cyan),
              _fact(Icons.favorite_rounded, '${level.hull}', 'HULL',
                  AppColors.danger),
              _fact(contract.icon, contract.name.split(' ').first, 'TYPE',
                  contract.color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: AppColors.textLow)),
        ],
      ),
    );
  }

  Widget _objectivesCard() {
    return GlassCard(
      tint: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 6),
              Text('STAR OBJECTIVES',
                  style: TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: AppColors.textHigh)),
            ],
          ),
          const SizedBox(height: 10),
          for (final o in level.objectives)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.14),
                    ),
                    child: Icon(o.icon, size: 17, color: AppColors.gold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(o.label,
                        style: const TextStyle(
                            fontFamily: AppText.body,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white)),
                  ),
                  const Icon(Icons.star_border_rounded,
                      size: 18, color: AppColors.textLow),
                ],
              ),
            ),
          Text(
            level.isBoss
                ? 'Destroying the gunship is required. Each objective met adds one star.'
                : 'Finishing the route is required. Each objective met adds one star.',
            style: const TextStyle(
                fontFamily: AppText.body,
                fontSize: 11,
                color: AppColors.textLow),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard(GameState gs) {
    final firstClear = !gs.levelCleared(level.id);
    return GlassCard(
      tint: AppColors.green,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.paid_rounded, color: AppColors.green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(firstClear ? 'First clear bonus' : 'Already cleared',
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white)),
                Text(
                    firstClear
                        ? 'Plus the credits you earn on the route'
                        : 'Replay for credits and better stars',
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 11,
                        color: AppColors.textMid)),
              ],
            ),
          ),
          Text(firstClear ? '+${level.reward}' : '—',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: AppColors.green)),
        ],
      ),
    );
  }
}
