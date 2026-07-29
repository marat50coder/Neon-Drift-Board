import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated neon backdrop shared by every screen. A single accent color keeps
/// screens cohesive while letting each screen feel distinct.
class NeonBackground extends StatefulWidget {
  final Widget child;
  final Color accent;
  final Color accent2;
  final bool grid;
  final int particles;

  const NeonBackground({
    super.key,
    required this.child,
    this.accent = AppColors.cyan,
    this.accent2 = AppColors.purple,
    this.grid = true,
    this.particles = 22,
  });

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_P> _pts;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.accent.toARGB32() ^ widget.particles);
    _pts = List.generate(
      widget.particles,
      (_) => _P(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        r: rng.nextDouble() * 2.4 + 0.6,
        speed: rng.nextDouble() * 0.05 + 0.015,
        drift: (rng.nextDouble() - 0.5) * 0.02,
        phase: rng.nextDouble() * pi * 2,
      ),
    );
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bg, AppColors.bgDeep],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _BgPainter(_c.value, _pts, widget.accent, widget.accent2,
                  widget.grid),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _P {
  double x, y, r, speed, drift, phase;
  _P({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.drift,
    required this.phase,
  });
}

class _BgPainter extends CustomPainter {
  final double t;
  final List<_P> pts;
  final Color accent;
  final Color accent2;
  final bool grid;
  _BgPainter(this.t, this.pts, this.accent, this.accent2, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    // Top glow.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(
          Rect.fromCircle(center: Offset(size.width * 0.5, -40), radius: size.width * 0.8));
    canvas.drawRect(Offset.zero & size, glow);

    // Bottom accent glow.
    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [accent2.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height + 40),
          radius: size.width * 0.9));
    canvas.drawRect(Offset.zero & size, glow2);

    if (grid) {
      _drawGrid(canvas, size);
    }

    // Particles (no MaskFilter — cheap solid circles with alpha halo).
    final paint = Paint();
    for (final p in pts) {
      final py = (p.y - (t * p.speed * 6)) % 1.0;
      final px = (p.x + sin(t * 2 * pi + p.phase) * p.drift) % 1.0;
      final o = 0.35 + 0.35 * sin(t * 2 * pi + p.phase);
      final c = Color.lerp(accent, accent2, px)!;
      final pos = Offset(px * size.width, (1 - py) * size.height);
      paint.color = c.withValues(alpha: (o * 0.35).clamp(0.05, 0.35));
      canvas.drawCircle(pos, p.r * 2.4, paint);
      paint.color = c.withValues(alpha: o.clamp(0.15, 0.8));
      canvas.drawCircle(pos, p.r, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final horizon = size.height * 0.62;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    // Perspective horizontal lines.
    for (int i = 0; i < 14; i++) {
      final f = i / 14;
      final y = horizon + (size.height - horizon) * f * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical converging lines.
    final cx = size.width / 2;
    for (int i = -8; i <= 8; i++) {
      final x = cx + i * (size.width / 10);
      canvas.drawLine(Offset(cx + i * 8.0, horizon), Offset(x, size.height),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.t != t;
}

/// Frosted glass surface used for cards and panels.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? border;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.border,
    this.blur = 14,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = border ?? Colors.white.withValues(alpha: 0.10);
    final base = tint ?? Colors.white;
    // Solid glass-like gradient without BackdropFilter — visually similar but
    // dramatically cheaper on GPU (important on screens with many cards).
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(base.withValues(alpha: 0.10), AppColors.surfaceHigh),
            Color.alphaBlend(base.withValues(alpha: 0.03), AppColors.surface),
          ],
        ),
        border: Border.all(color: b, width: 1.2),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
