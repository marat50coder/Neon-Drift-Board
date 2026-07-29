import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final entries = gs.leaderboard;
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.gold,
        accent2: AppColors.cyan,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'Leaderboard', accent: AppColors.gold),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 58),
                  child: Text('Your top delivery runs',
                      style: TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 13,
                          color: AppColors.textMid)),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: entries.isEmpty
                      ? _empty()
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            return _row(i + 1, e.name, e.score, e.districtName);
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

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64, color: AppColors.textLow),
          const SizedBox(height: 12),
          const Text('No runs yet',
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontSize: 18,
                  color: AppColors.textMid)),
          const SizedBox(height: 4),
          const Text('Complete a delivery to set a record.',
              style: TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 13,
                  color: AppColors.textLow)),
        ],
      ),
    );
  }

  Widget _row(int rank, String name, int score, String district) {
    final medal = rank == 1
        ? AppColors.gold
        : rank == 2
            ? const Color(0xFFC9D6FF)
            : rank == 3
                ? const Color(0xFFFF9A62)
                : AppColors.textLow;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: rank <= 3 ? medal.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: rank <= 3
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 26)
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textMid)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
                Text(district,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 12,
                        color: AppColors.textMid)),
              ],
            ),
          ),
          Text('$score',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.cyan)),
        ],
      ),
    );
  }
}
