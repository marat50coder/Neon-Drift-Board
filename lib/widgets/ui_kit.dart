import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../theme/app_theme.dart';

/// Primary gradient action button with a neon glow and press feedback.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final List<Color> colors;
  final double height;
  final bool dense;
  final bool enabled;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.colors = AppColors.primaryGradient,
    this.height = 56,
    this.dense = false,
    this.enabled = true,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
            }
          : null,
      onTap: enabled
          ? () {
              Audio.I.play('click');
              Audio.I.haptic();
              widget.onTap!.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.dense ? 18 : 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: LinearGradient(colors: widget.colors),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.first.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.black, size: 22),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.1,
                      color: Colors.black,
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
}

/// Outlined neon button for secondary actions.
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final double height;

  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = AppColors.cyan,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              Audio.I.play('click');
              Audio.I.haptic();
              onTap!.call();
            },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
          color: color.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular icon button (used for back buttons / toolbar actions).
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.cyan,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Audio.I.play('click');
        Audio.I.haptic();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

/// Credits pill with coin icon.
class CreditChip extends StatelessWidget {
  final int credits;
  final VoidCallback? onTap;
  const CreditChip({super.key, required this.credits, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          gradient: LinearGradient(colors: [
            AppColors.gold.withValues(alpha: 0.16),
            AppColors.gold.withValues(alpha: 0.04),
          ]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.paid_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 7),
            Text(
              _fmt(credits),
              style: const TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

/// Screen header with a neon accent bar + optional subtitle.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accent;
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 26,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 10)
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: 1.2,
                  color: AppColors.textHigh,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 4),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: AppText.body,
                fontSize: 14,
                color: AppColors.textMid,
              ),
            ),
          ),
      ],
    );
  }
}

/// Rarity badge chip.
class RarityBadge extends StatelessWidget {
  final String rarity;
  const RarityBadge({super.key, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.rarity(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c.withValues(alpha: 0.16),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        rarity.toUpperCase(),
        style: TextStyle(
          fontFamily: AppText.display,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.8,
          color: c,
        ),
      ),
    );
  }
}

/// Simple back-enabled scaffold-less top bar for sub screens.
class TopBar extends StatelessWidget {
  final String title;
  final Color accent;
  final List<Widget> actions;
  const TopBar({
    super.key,
    required this.title,
    this.accent = AppColors.cyan,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NeonIconButton(
          icon: Icons.arrow_back_rounded,
          color: accent,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: AppText.display,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: 1.1,
              color: AppColors.textHigh,
            ),
          ),
        ),
        ...actions,
      ],
    );
  }
}
