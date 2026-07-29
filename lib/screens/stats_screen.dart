import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final km = (gs.stat('distance') / 1000).toStringAsFixed(2);
    final time = (gs.stat('timePlayed') / 60).toStringAsFixed(0);

    final barData = <String, double>{
      'Deliver': gs.stat('deliveries').toDouble(),
      'Spheres': gs.stat('spheresCollected').toDouble(),
      'Crystal': gs.stat('crystalsCollected').toDouble(),
      'Drifts': gs.stat('drifts').toDouble(),
      'Turbos': gs.stat('turbos').toDouble(),
    };
    final maxY = (barData.values.fold<double>(1, (a, b) => a > b ? a : b)) * 1.2;

    final boardsPct = gs.boards.length / Catalog.boards.length;
    final spheresPct = gs.spheres.length / Catalog.spheres.length;
    final districtsPct = gs.districts.length / Catalog.districts.length;

    return Scaffold(
      body: NeonBackground(
        accent: AppColors.blue,
        accent2: AppColors.cyan,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'Statistics', accent: AppColors.blue),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          children: [
                            _tile(Icons.emoji_events_rounded, 'Best Score',
                                '${gs.stat('bestScore').toInt()}', AppColors.gold),
                            _tile(Icons.route_rounded, 'Distance', '$km km',
                                AppColors.cyan),
                            _tile(Icons.local_shipping_rounded, 'Deliveries',
                                '${gs.stat('deliveries').toInt()}',
                                AppColors.green),
                            _tile(Icons.sports_esports_rounded, 'Total Runs',
                                '${gs.stat('totalRuns').toInt()}',
                                AppColors.magenta),
                            _tile(Icons.local_fire_department_rounded,
                                'Best Combo', 'x${gs.stat('bestCombo').toInt()}',
                                AppColors.pink),
                            _tile(Icons.timer_rounded, 'Time', '$time min',
                                AppColors.purple),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ACTIVITY',
                                  style: TextStyle(
                                      fontFamily: AppText.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMid)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 180,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxY < 5 ? 5 : maxY,
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          getTitlesWidget: (v, meta) {
                                            final keys =
                                                barData.keys.toList();
                                            final i = v.toInt();
                                            if (i < 0 || i >= keys.length) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(keys[i],
                                                  style: const TextStyle(
                                                      fontFamily: AppText.body,
                                                      fontSize: 10,
                                                      color: AppColors.textMid)),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: [
                                      for (var i = 0;
                                          i < barData.length;
                                          i++)
                                        BarChartGroupData(x: i, barRods: [
                                          BarChartRodData(
                                            toY: barData.values.elementAt(i),
                                            width: 20,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            gradient: const LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                AppColors.blue,
                                                AppColors.cyan
                                              ],
                                            ),
                                          ),
                                        ]),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('COLLECTION',
                                  style: TextStyle(
                                      fontFamily: AppText.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 1.5,
                                      color: AppColors.textMid)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _radial('Boards', boardsPct, AppColors.cyan),
                                  _radial('Spheres', spheresPct,
                                      AppColors.magenta),
                                  _radial('Districts', districtsPct,
                                      AppColors.purple),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _tile(IconData ic, String label, String value, Color c) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(ic, color: c, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.white)),
                Text(label,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 11,
                        color: AppColors.textMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radial(String label, double pct, Color c) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 42,
          lineWidth: 8,
          percent: pct.clamp(0.0, 1.0),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          progressColor: c,
          circularStrokeCap: CircularStrokeCap.round,
          center: Text('${(pct * 100).round()}%',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontFamily: AppText.body,
                fontSize: 12,
                color: AppColors.textMid)),
      ],
    );
  }
}
