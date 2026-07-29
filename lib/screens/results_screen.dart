import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/catalog.dart';
import '../data/levels.dart';
import '../data/models.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'game_screen.dart';

class ResultsScreen extends StatefulWidget {
  final RunResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.result.delivered) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Color get _ratingColor {
    switch (widget.result.rating) {
      case 'Platinum':
        return AppColors.cyan;
      case 'Gold':
        return AppColors.gold;
      case 'Silver':
        return const Color(0xFFC9D6FF);
      case 'Bronze':
        return const Color(0xFFFF9A62);
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final delivered = r.delivered;
    final accent = delivered ? _ratingColor : AppColors.danger;
    final contract = Catalog.contracts
        .firstWhere((c) => c.id == r.contractId, orElse: () => Catalog.contracts.first);
    final mode = Modes.byId(r.modeId);
    final level = r.levelId == null ? null : Campaign.byId(r.levelId!);

    return Scaffold(
      body: NeonBackground(
        accent: accent,
        accent2: AppColors.purple,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: pi / 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 16,
                  maxBlastForce: 22,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const [
                    AppColors.cyan,
                    AppColors.magenta,
                    AppColors.purple,
                    AppColors.gold,
                  ],
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.modeId == 'boss'
                                ? (delivered ? 'GUNSHIP DOWN' : 'BOARD DESTROYED')
                                : (delivered
                                    ? 'DELIVERY COMPLETE'
                                    : 'DELIVERY FAILED'),
                            style: TextStyle(
                              fontFamily: AppText.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              letterSpacing: 2,
                              color: accent,
                              shadows: [
                                Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 20)
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: -0.4),
                          const SizedBox(height: 4),
                          Text(
                              level != null
                                  ? 'Level ${level.number} · ${level.name}'
                                  : '${mode.name} · ${contract.name}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: AppText.body,
                                  fontSize: 15,
                                  color: AppColors.textMid)),
                          if (level != null) ...[
                            const SizedBox(height: 12),
                            _stars(r),
                            const SizedBox(height: 10),
                            _objectiveList(level, r),
                          ],
                          const SizedBox(height: 14),
                          _ratingBadge(accent).animate().scale(
                              begin: const Offset(0.6, 0.6),
                              duration: 400.ms,
                              curve: Curves.elasticOut),
                          const SizedBox(height: 18),
                          GlassCard(
                            tint: accent,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('${r.score}',
                                        style: const TextStyle(
                                            fontFamily: AppText.display,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 48,
                                            color: Colors.white)),
                                    const SizedBox(width: 8),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text('PTS',
                                          style: TextStyle(
                                              fontFamily: AppText.display,
                                              fontSize: 16,
                                              color: AppColors.textMid)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _stat(Icons.route_rounded,
                                        '${r.distance.round()} m', 'Distance'),
                                    _stat(Icons.blur_circular_rounded,
                                        '${r.spheres}', 'Spheres', SpriteView(sheet: Sprites.spheres, index: 0, width: 26, height: 26)),
                                    _stat(Icons.diamond_rounded, '${r.crystals}',
                                        'Crystals'),
                                    _stat(Icons.local_fire_department_rounded,
                                        'x${r.bestCombo}', 'Best combo'),
                                    _stat(Icons.bolt_rounded, '${r.turbos}',
                                        'Turbos'),
                                    _stat(Icons.motion_photos_on_rounded,
                                        '${r.drifts}', 'Drifts'),
                                    _stat(Icons.bolt_rounded, '${r.grazes}',
                                        'Grazes'),
                                    _stat(Icons.threesixty_rounded,
                                        '${r.tricks}', 'Tricks'),
                                    if (r.modeId == 'time_attack')
                                      _stat(Icons.timer_rounded,
                                          '${r.modeValue.ceil()}s', 'Time left'),
                                    if (r.modeId == 'precision')
                                      _stat(Icons.link_rounded,
                                          'x${r.modeValue.round()}', 'Best chain'),
                                    if (r.modeId == 'endless')
                                      _stat(Icons.hourglass_bottom_rounded,
                                          '${r.modeValue.round()}s', 'Survived'),
                                    if (r.modeId == 'flight')
                                      _stat(Icons.radio_button_unchecked_rounded,
                                          '${r.modeValue.round()}', 'Rings'),
                                    if (r.modeId == 'boss')
                                      _stat(Icons.smart_toy_rounded,
                                          '${r.modeValue.round()}%', 'Hull torn'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(colors: [
                                AppColors.gold.withValues(alpha: 0.2),
                                AppColors.gold.withValues(alpha: 0.05),
                              ]),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.paid_rounded,
                                    color: AppColors.gold, size: 24),
                                const SizedBox(width: 8),
                                Text('+${r.credits} CREDITS',
                                    style: const TextStyle(
                                        fontFamily: AppText.display,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: AppColors.gold)),
                              ],
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.4),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: GhostButton(
                                  label: 'Home',
                                  icon: Icons.home_rounded,
                                  onTap: () => Navigator.of(context)
                                      .popUntil((r) => r.isFirst),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: NeonButton(
                                  label: 'Play Again',
                                  icon: Icons.refresh_rounded,
                                  onTap: () => Navigator.of(context)
                                      .pushReplacement(MaterialPageRoute(
                                          builder: (_) => GameScreen(
                                                contract: contract,
                                                mode: mode.mode,
                                                level: level,
                                              ))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stars(RunResult r) {
    final earned = r.stars;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i < earned;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 42,
            color: on ? AppColors.gold : Colors.white24,
          )
              .animate(delay: (160 * i).ms)
              .scale(begin: const Offset(0.3, 0.3), curve: Curves.elasticOut),
        );
      }),
    );
  }

  Widget _objectiveList(LevelDef level, RunResult r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < level.objectives.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  i < r.objectivesMet.length && r.objectivesMet[i]
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 15,
                  color: i < r.objectivesMet.length && r.objectivesMet[i]
                      ? AppColors.green
                      : AppColors.textLow,
                ),
                const SizedBox(width: 6),
                Text(level.objectives[i].label,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 12.5,
                        color: AppColors.textMid)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ratingBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: accent, width: 2),
        color: accent.withValues(alpha: 0.12),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 24)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: accent, size: 26),
          const SizedBox(width: 10),
          Text(widget.result.rating.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 2,
                  color: accent)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, [Widget? custom]) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          custom ?? Icon(icon, color: AppColors.cyan, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontSize: 11,
                  color: AppColors.textMid)),
        ],
      ),
    );
  }
}
