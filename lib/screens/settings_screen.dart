import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_background.dart';
import '../widgets/ui_kit.dart';
import 'about_screen.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _privacyUrl = 'https://neondriftboard.com/privacy-policy.html';
  static const _supportUrl = 'https://neondriftboard.com/support.html';

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: NeonBackground(
        accent: AppColors.cyan,
        accent2: AppColors.blue,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(title: 'Settings', accent: AppColors.cyan),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GlassCard(
                          child: Column(
                            children: [
                              _sectionLabel('AUDIO & FEEL'),
                              _switch('Sound Effects', gs.sfxOn,
                                  Icons.graphic_eq_rounded,
                                  (v) => gs.updateSettings(sfx: v)),
                              if (gs.sfxOn)
                                _slider('SFX Volume', gs.sfxVolume,
                                    (v) => gs.updateSettings(sfxVol: v)),
                              _divider(),
                              _switch('Music', gs.musicOn,
                                  Icons.music_note_rounded,
                                  (v) => gs.updateSettings(music: v)),
                              if (gs.musicOn)
                                _slider('Music Volume', gs.musicVolume,
                                    (v) => gs.updateSettings(musicVol: v)),
                              _divider(),
                              _switch('Vibration', gs.hapticsOn,
                                  Icons.vibration_rounded,
                                  (v) => gs.updateSettings(haptics: v)),
                              _divider(),
                              _switch('Visual Effects', gs.showFx,
                                  Icons.auto_awesome_rounded,
                                  (v) => gs.updateSettings(fx: v)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('CONTROLS'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _controlOption(gs, 'swipe', 'Swipe',
                                      Icons.swipe_rounded),
                                  const SizedBox(width: 10),
                                  _controlOption(gs, 'buttons', 'Buttons',
                                      Icons.gamepad_rounded),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Column(
                            children: [
                              _sectionLabel('ABOUT & LEGAL'),
                              _link(context, 'Privacy Policy',
                                  Icons.privacy_tip_rounded, () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => const WebViewScreen(
                                          title: 'Privacy Policy',
                                          url: _privacyUrl,
                                          assetFallback:
                                              'assets/legal/privacy_policy.html',
                                          accent: AppColors.cyan,
                                        )));
                              }),
                              _divider(),
                              _link(context, 'Support', Icons.support_agent_rounded,
                                  () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => const WebViewScreen(
                                          title: 'Support',
                                          url: _supportUrl,
                                          assetFallback:
                                              'assets/legal/support.html',
                                          accent: AppColors.magenta,
                                        )));
                              }),
                              _divider(),
                              _link(context, 'About', Icons.info_rounded, () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => const AboutScreen()));
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GhostButton(
                          label: 'Reset Progress',
                          icon: Icons.restart_alt_rounded,
                          color: AppColors.danger,
                          onTap: () => _confirmReset(context, gs),
                        ),
                        const SizedBox(height: 10),
                        const Text('Version 1.0.0',
                            style: TextStyle(
                                fontFamily: AppText.body,
                                fontSize: 12,
                                color: AppColors.textLow)),
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

  Widget _sectionLabel(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                  color: AppColors.textMid)),
        ),
      );

  Widget _divider() => Divider(
      color: Colors.white.withValues(alpha: 0.08), height: 20);

  Widget _switch(
      String label, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyan, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontFamily: AppText.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white)),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.cyan,
          onChanged: (v) {
            Audio.I.play('click');
            onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        const SizedBox(width: 34),
        Text(label,
            style: const TextStyle(
                fontFamily: AppText.body,
                fontSize: 13,
                color: AppColors.textMid)),
        Expanded(
          child: Slider(
            value: value,
            activeColor: AppColors.cyan,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontSize: 13,
                  color: AppColors.textMid)),
        ),
      ],
    );
  }

  Widget _controlOption(
      GameState gs, String id, String label, IconData icon) {
    final active = gs.controlMode == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Audio.I.play('click');
          gs.updateSettings(control: id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: active
                ? AppColors.cyan.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
                color: active ? AppColors.cyan : Colors.white24, width: 1.4),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? AppColors.cyan : AppColors.textMid),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontFamily: AppText.body,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textMid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: AppText.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMid),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, GameState gs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Progress?',
            style: TextStyle(fontFamily: AppText.display, color: Colors.white)),
        content: const Text(
            'This permanently erases credits, unlocks, stats and settings.',
            style: TextStyle(fontFamily: AppText.body, color: AppColors.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMid))),
          TextButton(
              onPressed: () {
                gs.resetProgress();
                Navigator.pop(context);
              },
              child: const Text('Reset',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }
}
