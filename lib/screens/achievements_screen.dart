import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final unlocked =
        Catalog.achievements.where((a) => gs.achievementUnlocked(a)).length;
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.gold,
        accent2: AppColors.magenta,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TopBar(
                          title: 'Achievements', accent: AppColors.gold),
                    ),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Text('$unlocked / ${Catalog.achievements.length} unlocked',
                      style: const TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 13,
                          color: AppColors.textMid)),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 600,
                      childAspectRatio: 3.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: Catalog.achievements.length,
                    itemBuilder: (_, i) =>
                        _AchCard(def: Catalog.achievements[i], gs: gs),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchCard extends StatelessWidget {
  final AchievementDef def;
  final GameState gs;
  const _AchCard({required this.def, required this.gs});

  @override
  Widget build(BuildContext context) {
    final progress = gs.achievementProgress(def);
    final unlocked = gs.achievementUnlocked(def);
    final claimed = gs.achievementClaimed(def);
    final pct = (progress / def.target).clamp(0.0, 1.0);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      border: unlocked && !claimed ? AppColors.gold : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (unlocked ? AppColors.gold : AppColors.textLow)
                  .withValues(alpha: 0.16),
              border: Border.all(
                  color: (unlocked ? AppColors.gold : AppColors.textLow)
                      .withValues(alpha: 0.5)),
            ),
            child: Icon(def.icon,
                color: unlocked ? AppColors.gold : AppColors.textLow, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white)),
                Text(def.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 11.5,
                        color: AppColors.textMid)),
                const SizedBox(height: 6),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  lineHeight: 6,
                  percent: pct,
                  barRadius: const Radius.circular(4),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  linearGradient: const LinearGradient(
                      colors: [AppColors.gold, Color(0xFFFF8A3D)]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _trailing(),
        ],
      ),
    );
  }

  Widget _trailing() {
    if (gs.achievementClaimed(def)) {
      return const Icon(Icons.verified_rounded, color: AppColors.green);
    }
    if (gs.achievementUnlocked(def)) {
      return GestureDetector(
        onTap: () {
          Audio.I.play('crystal');
          gs.claimAchievement(def);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: AppColors.goldGradient),
          ),
          child: Text('+${def.reward}',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.black)),
        ),
      );
    }
    return Text('+${def.reward}',
        style: const TextStyle(
            fontFamily: AppText.display,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textLow));
  }
}
