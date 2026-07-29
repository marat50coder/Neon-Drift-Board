import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class DistrictsScreen extends StatelessWidget {
  const DistrictsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.purple,
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
                        child: TopBar(
                            title: 'Districts', accent: AppColors.purple)),
                    CreditChip(credits: gs.credits),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: Catalog.districts.length,
                    itemBuilder: (_, i) =>
                        _DistrictCard(district: Catalog.districts[i], gs: gs),
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

class _DistrictCard extends StatelessWidget {
  final District district;
  final GameState gs;
  const _DistrictCard({required this.district, required this.gs});

  @override
  Widget build(BuildContext context) {
    final owned = gs.districts.contains(district.id);
    final selected = gs.district == district.id;
    final asset =
        'assets/Neon_Drift_Board_gameplay_assets/bg_location_${district.index + 1}_asset.webp';

    return GestureDetector(
      onTap: () {
        Audio.I.play('click');
        if (owned) {
          gs.select('district', district.id);
        } else {
          final ok = gs.buy('district', district.id, district.unlockCost);
          if (ok) {
            gs.select('district', district.id);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Need ${district.unlockCost} credits'),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            if (!owned) ...[
              Container(color: Colors.black.withValues(alpha: 0.35)),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withValues(alpha: 0.7),
                    border:
                        Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded,
                          color: AppColors.gold, size: 13),
                      const SizedBox(width: 5),
                      Text('${district.unlockCost}',
                          style: const TextStyle(
                              fontFamily: AppText.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ],
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(district.name,
                            style: const TextStyle(
                                fontFamily: AppText.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white)),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 18),
                      ],
                    ],
                  ),
                  Text(district.vibe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppText.body,
                          fontSize: 12,
                          color: AppColors.textMid)),
                ],
              ),
            ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.green, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
