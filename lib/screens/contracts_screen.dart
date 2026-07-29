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

class ContractsScreen extends StatelessWidget {
  /// Which rule set the chosen contract will be played under.
  final GameMode mode;
  const ContractsScreen({super.key, this.mode = GameMode.campaign});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final district = Catalog.districts.firstWhere((d) => d.id == gs.district,
        orElse: () => Catalog.districts.first);
    final info = Modes.info(mode);
    return Scaffold(
      body: NeonBackground(
        accent: info.color,
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
                      child: TopBar(title: info.name, accent: info.color),
                    ),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 15, color: AppColors.cyan),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${district.name} · Pick a contract',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppText.body,
                                fontSize: 13,
                                color: AppColors.textMid)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _modeBanner(info),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 560,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: Catalog.contracts.length,
                    itemBuilder: (_, i) {
                      final c = Catalog.contracts[i];
                      return _ContractCard(contract: c, mode: mode)
                          .animate()
                          .fadeIn(delay: (i * 60).ms)
                          .slideY(begin: 0.2);
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

  Widget _modeBanner(GameModeInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: info.color.withValues(alpha: 0.12),
        border: Border.all(color: info.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(info.icon, size: 17, color: info.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(info.rules,
                maxLines: 2,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.textMid)),
          ),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final ContractType contract;
  final GameMode mode;
  const _ContractCard({required this.contract, required this.mode});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: contract.color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: contract.color.withValues(alpha: 0.16),
                  border:
                      Border.all(color: contract.color.withValues(alpha: 0.6)),
                ),
                child: Icon(contract.icon, color: contract.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(contract.name,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(contract.description,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontSize: 13,
                    height: 1.3,
                    color: AppColors.textMid)),
          ),
          Row(
            children: [
              _chip(Icons.speed_rounded, '${contract.speedMul.toStringAsFixed(2)}x',
                  AppColors.cyan),
              const SizedBox(width: 8),
              _chip(Icons.paid_rounded,
                  '${contract.rewardMul.toStringAsFixed(1)}x', AppColors.gold),
              const Spacer(),
              GhostButton(
                label: 'Go',
                icon: Icons.play_arrow_rounded,
                height: 40,
                color: contract.color,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        GameScreen(contract: contract, mode: mode))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData ic, String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 13, color: c),
          const SizedBox(width: 4),
          Text(t,
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: c)),
        ],
      ),
    );
  }
}
