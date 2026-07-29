import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/game_state.dart';
import '../data/upgrades.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

/// Workshop: permanent upgrades that change the simulation, not the looks.
class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final installed =
        gs.upgradeLevels.values.fold<int>(0, (s, v) => s + v);

    return Scaffold(
      body: NeonBackground(
        accent: AppColors.blue,
        accent2: AppColors.green,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  title: 'Workshop',
                  accent: AppColors.blue,
                  actions: [CreditChip(credits: gs.credits)],
                ),
                const SizedBox(height: 12),
                _summary(installed),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: Upgrades.all.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _UpgradeRow(def: Upgrades.all[i])
                        .animate()
                        .fadeIn(delay: (i * 45).ms),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(int installed) {
    return GlassCard(
      tint: AppColors.blue,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.build_rounded, color: AppColors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BOARD SYSTEMS',
                    style: TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: AppColors.textHigh)),
                const SizedBox(height: 2),
                Text(
                    'Every upgrade level changes how the board actually plays.',
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 11.5,
                        color: AppColors.textMid)),
              ],
            ),
          ),
          Text('$installed/${Upgrades.maxTotalLevels}',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.blue)),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  final UpgradeDef def;
  const _UpgradeRow({required this.def});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final level = gs.upgradeLevel(def.id);
    final maxed = gs.upgradeMaxed(def);
    final cost = gs.upgradeCost(def);
    final affordable = cost != null && gs.credits >= cost;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                def.color.withValues(alpha: 0.16), AppColors.surfaceHigh),
            Color.alphaBlend(
                def.color.withValues(alpha: 0.03), AppColors.surface),
          ],
        ),
        border: Border.all(
            color: def.color.withValues(alpha: maxed ? 0.65 : 0.34)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: def.color.withValues(alpha: 0.16),
                  border: Border.all(color: def.color.withValues(alpha: 0.55)),
                ),
                child: Icon(def.icon, color: def.color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(def.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppText.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Colors.white)),
                    Text(def.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppText.body,
                            fontSize: 11.5,
                            height: 1.25,
                            color: AppColors.textMid)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Level pips make the progression readable at a glance.
              Row(
                children: List.generate(
                  def.maxLevel,
                  (i) => Container(
                    width: 16,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < level
                          ? def.color
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(level > 0 ? def.format(level) : 'stock',
                  style: TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: level > 0 ? def.color : AppColors.textLow)),
              const Spacer(),
              if (maxed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: def.color.withValues(alpha: 0.16),
                  ),
                  child: Text('MAX',
                      style: TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: def.color)),
                )
              else
                GestureDetector(
                  onTap: affordable
                      ? () {
                          if (gs.buyUpgrade(def)) {
                            Audio.I.play('checkpoint');
                            Audio.I.haptic();
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: affordable
                          ? def.color.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                          color: affordable
                              ? def.color.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.paid_rounded,
                            size: 14,
                            color:
                                affordable ? AppColors.gold : AppColors.textLow),
                        const SizedBox(width: 5),
                        Text('$cost',
                            style: TextStyle(
                                fontFamily: AppText.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: affordable
                                    ? Colors.white
                                    : AppColors.textLow)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
