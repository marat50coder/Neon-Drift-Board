import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/levels.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'level_brief_screen.dart';

/// Campaign route map: 24 levels grouped into acts, unlocked in sequence.
class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    // Group levels by their district so the map reads as a set of acts.
    final acts = <int, List<LevelDef>>{};
    for (final l in Campaign.levels) {
      acts.putIfAbsent(l.districtIndex, () => []).add(l);
    }

    return Scaffold(
      body: NeonBackground(
        accent: AppColors.cyan,
        accent2: AppColors.purple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  title: 'Campaign',
                  accent: AppColors.cyan,
                  actions: [_starCounter(gs)],
                ),
                const SizedBox(height: 12),
                _progressCard(gs),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      for (final entry in acts.entries) ...[
                        _actHeader(entry.key),
                        const SizedBox(height: 10),
                        for (final level in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LevelNode(level: level),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _starCounter(GameState gs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.gold.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
          const SizedBox(width: 4),
          Text('${gs.totalStars}/${Campaign.totalStars}',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _progressCard(GameState gs) {
    final cleared = gs.campaignCleared;
    final total = Campaign.levels.length;
    return GlassCard(
      tint: AppColors.cyan,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('ROUTE PROGRESS',
                  style: TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: AppColors.textMid)),
              const Spacer(),
              Text('$cleared / $total',
                  style: const TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : cleared / total,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cleared >= total
                ? 'Every route delivered. The city is yours.'
                : 'Next up: ${gs.nextLevel.name}',
            style: const TextStyle(
                fontFamily: AppText.body,
                fontSize: 12,
                color: AppColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _actHeader(int districtIndex) {
    final district = Catalog.districts.firstWhere(
        (d) => d.index == districtIndex,
        orElse: () => Catalog.districts.first);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.purple,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(district.name.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 2,
                color: AppColors.textHigh)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.purple.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

class _LevelNode extends StatelessWidget {
  final LevelDef level;
  const _LevelNode({required this.level});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final unlocked = gs.levelUnlocked(level);
    final stars = gs.starsFor(level.id);
    final cleared = stars > 0;
    final info = level.modeInfo;
    // Special levels wear their rule set's colour so the map reads as varied
    // at a glance, not as 24 identical rows.
    final baseAccent =
        level.mode == GameMode.campaign ? AppColors.cyan : info.color;
    final accent = cleared
        ? AppColors.green
        : unlocked
            ? baseAccent
            : AppColors.textLow;

    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: GestureDetector(
        onTap: unlocked
            ? () {
                Audio.I.play('open');
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LevelBriefScreen(level: level)));
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                    accent.withValues(alpha: 0.16), AppColors.surfaceHigh),
                Color.alphaBlend(
                    accent.withValues(alpha: 0.03), AppColors.surface),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              // Level number medallion.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: !unlocked
                    ? const Icon(Icons.lock_rounded,
                        size: 20, color: AppColors.textLow)
                    : level.isBoss
                        ? Icon(info.icon, size: 22, color: Colors.white)
                        : Text('${level.number}',
                            style: const TextStyle(
                                fontFamily: AppText.display,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(level.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppText.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (level.mode != GameMode.campaign) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: info.color.withValues(alpha: 0.16),
                              border: Border.all(
                                  color: info.color.withValues(alpha: 0.55)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(info.icon, size: 10, color: info.color),
                                const SizedBox(width: 4),
                                Text(info.name.toUpperCase(),
                                    style: TextStyle(
                                        fontFamily: AppText.display,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9,
                                        letterSpacing: 0.8,
                                        color: info.color)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          const Icon(Icons.straighten_rounded,
                              size: 12, color: AppColors.textLow),
                          const SizedBox(width: 3),
                          Text('${level.targetMeters.round()} m',
                              style: const TextStyle(
                                  fontFamily: AppText.body,
                                  fontSize: 11,
                                  color: AppColors.textMid)),
                          const SizedBox(width: 10),
                        ],
                        const Icon(Icons.favorite_rounded,
                            size: 12, color: AppColors.danger),
                        const SizedBox(width: 3),
                        Text('${level.hull}',
                            style: const TextStyle(
                                fontFamily: AppText.body,
                                fontSize: 11,
                                color: AppColors.textMid)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 17,
                    color: i < stars ? AppColors.gold : AppColors.textLow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 220.ms),
    );
  }
}
