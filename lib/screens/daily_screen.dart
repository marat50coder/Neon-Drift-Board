import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.green,
        accent2: AppColors.cyan,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                          TopBar(title: 'Daily Runs', accent: AppColors.green),
                    ),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 58),
                  child: Text('Resets every day · complete to earn credits',
                      style: TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 13,
                          color: AppColors.textMid)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: gs.daily.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _DailyCard(challenge: gs.daily[i], gs: gs),
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

class _DailyCard extends StatelessWidget {
  final DailyChallenge challenge;
  final GameState gs;
  const _DailyCard({required this.challenge, required this.gs});

  @override
  Widget build(BuildContext context) {
    final pct = (challenge.progress / challenge.target).clamp(0.0, 1.0);
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
            ),
            child: Icon(
              challenge.claimed
                  ? Icons.verified_rounded
                  : challenge.completed
                      ? Icons.check_circle_rounded
                      : Icons.flag_rounded,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(challenge.title,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  lineHeight: 8,
                  percent: pct,
                  barRadius: const Radius.circular(6),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  linearGradient:
                      const LinearGradient(colors: [AppColors.green, AppColors.cyan]),
                ),
                const SizedBox(height: 4),
                Text(
                    '${challenge.progress.clamp(0, challenge.target)} / ${challenge.target}',
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 12,
                        color: AppColors.textMid)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _reward(context),
        ],
      ),
    );
  }

  Widget _reward(BuildContext context) {
    if (challenge.claimed) {
      return const Column(
        children: [
          Icon(Icons.check_rounded, color: AppColors.green),
          Text('DONE',
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontSize: 10,
                  color: AppColors.green)),
        ],
      );
    }
    if (challenge.completed) {
      return NeonButton(
        label: '+${challenge.reward}',
        height: 44,
        dense: true,
        colors: AppColors.goldGradient,
        onTap: () {
          Audio.I.play('crystal');
          gs.claimDaily(challenge);
        },
      );
    }
    return Column(
      children: [
        const Icon(Icons.paid_rounded, color: AppColors.gold, size: 20),
        Text('${challenge.reward}',
            style: const TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.gold)),
      ],
    );
  }
}
