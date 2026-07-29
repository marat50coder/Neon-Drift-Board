import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _logo =
      'assets/Neon_Drift_Board_additional_assets/Game_Name.webp';

  @override
  Widget build(BuildContext context) {
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
                TopBar(title: 'About', accent: AppColors.magenta),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                            height: 120, child: Image.asset(_logo)),
                        const SizedBox(height: 8),
                        const Text(
                          'Become an underground courier in a sprawling '
                          'cyberpunk megacity. Ride your levitating board, '
                          'deliver high-energy neon spheres across procedurally '
                          'shifting routes, dodge police drones, chain drifts '
                          'and unleash turbo to earn the top rating.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: AppText.body,
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textMid),
                        ),
                        const SizedBox(height: 18),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _how(Icons.swipe_vertical_rounded,
                                  'Swipe up / down to switch lanes.'),
                              _how(Icons.touch_app_rounded,
                                  'Tap to jump over energy barriers.'),
                              _how(Icons.motion_photos_on_rounded,
                                  'Hold to drift and charge turbo.'),
                              _how(Icons.bolt_rounded,
                                  'Tap ⚡ to unleash turbo bursts.'),
                              _how(Icons.blur_circular_rounded,
                                  'Collect spheres & crystals for combos.'),
                              _how(Icons.route_rounded,
                                  'Fill the route bar to complete delivery.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Neon Drift Board',
                            style: TextStyle(
                                fontFamily: AppText.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white)),
                        const Text('Version 1.0.0',
                            style: TextStyle(
                                fontFamily: AppText.body,
                                fontSize: 13,
                                color: AppColors.textLow)),
                        const SizedBox(height: 4),
                        const Text('support@neondriftboard.com',
                            style: TextStyle(
                                fontFamily: AppText.body,
                                fontSize: 13,
                                color: AppColors.cyan)),
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

  Widget _how(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: AppText.body,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
