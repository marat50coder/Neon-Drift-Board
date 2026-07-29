import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/game_state.dart';
import '../data/levels.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'campaign_screen.dart';
import 'contracts_screen.dart';

/// Hub for the five rule sets. Campaign opens the level map; the free-play
/// modes go through contract selection so the player still picks a flavour.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  void _open(BuildContext context, GameModeInfo info) {
    Audio.I.play('open');
    final screen = info.mode == GameMode.campaign
        ? const CampaignScreen()
        : ContractsScreen(mode: info.mode);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.magenta,
        accent2: AppColors.cyan,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  title: 'Game Modes',
                  accent: AppColors.magenta,
                  actions: [CreditChip(credits: gs.credits)],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Five different rule sets — not five skins on the same run.',
                  style: TextStyle(
                      fontFamily: AppText.body,
                      fontSize: 12.5,
                      color: AppColors.textMid),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: Modes.all.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final info = Modes.all[i];
                      return _ModeCard(
                        info: info,
                        badge: info.mode == GameMode.campaign
                            ? '${gs.campaignCleared}/${Campaign.levels.length}'
                            : null,
                        onTap: () => _open(context, info),
                      )
                          .animate()
                          .fadeIn(delay: (i * 60).ms)
                          .slideY(begin: 0.1);
                    },
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

class _ModeCard extends StatelessWidget {
  final GameModeInfo info;
  final String? badge;
  final VoidCallback onTap;
  const _ModeCard({required this.info, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                  info.color.withValues(alpha: 0.20), AppColors.surfaceHigh),
              Color.alphaBlend(
                  info.color.withValues(alpha: 0.04), AppColors.surface),
            ],
          ),
          border: Border.all(color: info.color.withValues(alpha: 0.42)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: info.color.withValues(alpha: 0.16),
                    border:
                        Border.all(color: info.color.withValues(alpha: 0.6)),
                  ),
                  child: Icon(info.icon, color: info.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppText.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.white)),
                      Text(info.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppText.body,
                              fontSize: 12,
                              color: info.color)),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: info.color.withValues(alpha: 0.16),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            fontFamily: AppText.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: info.color)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(info.description,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textMid)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.28),
              ),
              child: Row(
                children: [
                  Icon(Icons.rule_rounded, size: 14, color: info.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(info.rules,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppText.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: AppColors.textMid)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: info.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
