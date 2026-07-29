import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A left-to-right filling neon progress bar with a moving highlight.
class NeonLoaderBar extends StatelessWidget {
  final double progress; // 0..1
  final double width;
  final double height;
  final List<Color> colors;

  const NeonLoaderBar({
    super.key,
    required this.progress,
    required this.width,
    this.height = 16,
    this.colors = const [AppColors.cyan, AppColors.magenta],
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: p <= 0 ? 0.001 : p,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(colors: colors),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.7),
                      blurRadius: 12,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: height * 0.6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.85),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
