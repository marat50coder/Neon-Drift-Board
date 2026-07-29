import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class _Lesson {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  const _Lesson(this.title, this.body, this.icon, this.color);
}

/// Paged how-to-play. Covers controls first, then the skill systems that make
/// the scoring interesting.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _lessons = <_Lesson>[
    _Lesson(
      'Switch lanes',
      'Swipe left or right to move between the three lanes. One swipe moves '
          'exactly one lane, so you can chain them safely.',
      Icons.swipe_rounded,
      AppColors.cyan,
    ),
    _Lesson(
      'Jump and trick',
      'Tap to jump over barriers. Tap again while airborne to spin — landing '
          'a full rotation pays a big score bonus and charges overdrive.',
      Icons.threesixty_rounded,
      AppColors.purple,
    ),
    _Lesson(
      'Drift for charge',
      'Press and hold to drift. Long drifts build your turbo tank and add to '
          'the combo chain. Release before you run out of road.',
      Icons.motion_photos_on_rounded,
      AppColors.magenta,
    ),
    _Lesson(
      'Graze the danger',
      'Passing a patrol or barrier at close range without touching it scores '
          'a GRAZE. It is the fastest way to build combo and overdrive.',
      Icons.bolt_rounded,
      AppColors.green,
    ),
    _Lesson(
      'Keep the combo alive',
      'Every pickup, graze and trick raises your combo up to x20 and refills '
          'the bar under it. Stop scoring for a few seconds and the combo '
          'ticks back down — a crash wipes it out completely.',
      Icons.local_fire_department_rounded,
      AppColors.pink,
    ),
    _Lesson(
      'Overdrive',
      'The gauge under your score fills from skilful play. At 100% it fires '
          'automatically: double score, a magnet and full immunity.',
      Icons.auto_awesome_rounded,
      AppColors.gold,
    ),
    _Lesson(
      'Power-ups',
      'Shield tokens absorb one impact. Magnet tokens pull spheres in from '
          'neighbouring lanes. Upgrade both in the Workshop.',
      Icons.shield_rounded,
      AppColors.blue,
    ),
    _Lesson(
      'Free flight',
      'Some routes have no lanes at all. Drag anywhere to fly the board in two '
          'axes — it carries momentum. Fly high for speed, low for reaction '
          'time, and tap for a barrel roll that dodges anything.',
      Icons.open_with_rounded,
      AppColors.blue,
    ),
    _Lesson(
      'Gunship duels',
      'Boss levels are a stand-up fight. Read the red telegraph columns and '
          'sweeping beams, gather spheres to charge your cannon, then tap to '
          'fire. Three phases — it gets faster as its armour falls.',
      Icons.gps_fixed_rounded,
      AppColors.danger,
    ),
    _Lesson(
      'Seven game modes',
      'The campaign rotates between lane routes, free flight and duels. '
          'Endless, Time Attack, Pursuit and Precision are there whenever you '
          'want to chase a score instead.',
      Icons.grid_view_rounded,
      AppColors.pink,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _lessons.length - 1) {
      context.read<GameState>().markTutorialSeen();
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lessons[_page];
    return Scaffold(
      body: NeonBackground(
        accent: lesson.color,
        accent2: AppColors.purple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'How to Play', accent: lesson.color),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _lessons.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _lessonPage(_lessons[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _lessons.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == _page ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _page
                            ? lesson.color
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: NeonButton(
                    label: _page >= _lessons.length - 1 ? 'Got it' : 'Next',
                    icon: _page >= _lessons.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lessonPage(_Lesson l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: l.color.withValues(alpha: 0.14),
              border: Border.all(color: l.color.withValues(alpha: 0.55), width: 2),
            ),
            child: Icon(l.icon, size: 52, color: l.color),
          )
              .animate(key: ValueKey(l.title))
              .fadeIn(duration: 260.ms)
              .scale(begin: const Offset(0.85, 0.85)),
          const SizedBox(height: 26),
          Text(l.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.white)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(l.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.textMid)),
          ),
        ],
      ),
    );
  }
}
