import 'dart:math';
import 'package:flutter/material.dart';

import '../data/levels.dart';
import '../theme/app_theme.dart';
import 'engine.dart';
import 'sprites.dart';

class GamePainter extends CustomPainter {
  final GameEngine e;
  GamePainter(this.e) : super(repaint: e);

  static const _particleColors = [
    AppColors.cyan,
    AppColors.magenta,
    AppColors.purple,
    AppColors.gold,
  ];
  static const _policeCarCells = [0, 1, 3, 5];

  // Cached paints (allocated per frame is fine for a few, but the ones we hit
  // in tight loops we reuse).
  final Paint _tmp = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    e.configure(size);
    if (e.shake > 0) {
      canvas.save();
      final s = e.shake;
      canvas.translate(
          (sin(e.distancePx * 0.7) * 8 * s),
          (cos(e.distancePx * 0.6) * 8 * s));
    }

    _drawBackground(canvas, size);
    if (e.freeControl) {
      _drawCorridor(canvas, size);
    } else {
      _drawRoad(canvas, size);
    }
    _drawEntities(canvas, size);
    _drawHunter(canvas, size);
    _drawBoss(canvas, size);
    _drawPlayer(canvas, size);
    _drawParticles(canvas);
    _drawFloaters(canvas, size);

    if (e.shake > 0) canvas.restore();

    // Overdrive tint — a warm energy wash pulsing over the whole screen.
    if (e.overdriveActive) {
      final p = 0.5 + 0.5 * sin(e.distancePx * 0.08);
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = AppColors.gold.withValues(alpha: 0.05 + 0.04 * p));
    }

    if (e.flash > 0) {
      canvas.drawRect(Offset.zero & size,
          _tmp..color = Colors.white.withValues(alpha: e.flash * 0.3));
    }
  }

  /// Pursuit mode: the hunter drone creeping up from behind the board.
  void _drawHunter(Canvas canvas, Size size) {
    if (e.mode != GameMode.pursuit) return;
    final y = e.playerDrawY + e.hunterGap;
    if (y > size.height + 120) return;

    final w = e.laneW * 0.9;
    final cx = size.width / 2;
    final pulse = 0.5 + 0.5 * sin(e.hunterPhase * 7);
    // Danger wash rising from the bottom as it closes.
    final closeness =
        (1 - (e.hunterGap / GameEngine.hunterMaxGap)).clamp(0.0, 1.0);
    if (closeness > 0.15) {
      final h = size.height * 0.42;
      canvas.drawRect(
          Rect.fromLTWH(0, size.height - h, size.width, h),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.danger
                    .withValues(alpha: 0.22 * closeness * (0.7 + 0.3 * pulse)),
                Colors.transparent,
              ],
            ).createShader(
                Rect.fromLTWH(0, size.height - h, size.width, h)));
    }

    // Drone body: an angular wedge with a scanning eye.
    final body = Path()
      ..moveTo(cx, y - w * 0.42)
      ..lineTo(cx + w * 0.5, y + w * 0.26)
      ..lineTo(cx, y + w * 0.1)
      ..lineTo(cx - w * 0.5, y + w * 0.26)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xEE160411));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.danger.withValues(alpha: 0.75 + 0.25 * pulse));
    canvas.drawCircle(
        Offset(cx, y - w * 0.08),
        w * 0.13,
        Paint()
          ..color = AppColors.danger.withValues(alpha: 0.55 + 0.45 * pulse));
  }

  void _drawFloaters(Canvas canvas, Size size) {
    if (e.floaters.isEmpty) return;
    const colors = [
      AppColors.cyan,
      AppColors.gold,
      AppColors.magenta,
      AppColors.green,
      Colors.white,
    ];
    for (final f in e.floaters) {
      final t = (f.life / f.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w800,
            fontSize: 17 * f.scale,
            letterSpacing: 1,
            color: colors[f.color % colors.length].withValues(alpha: t),
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - tp.height / 2));
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final img = Sprites.I.img(Sprites.I.bgKey(e.district.index));
    if (img == null) {
      canvas.drawRect(Offset.zero & size, _tmp..color = AppColors.bg);
      return;
    }
    // Static background — fill the screen once, no tiling, no seams.
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low);
  }

  void _drawRoad(Canvas canvas, Size size) {
    final turbo = e.turboActive;
    final boosting = e.boostTimer > 0;
    final intensity = turbo ? 1.0 : (boosting ? 0.72 : 0.42);

    // 1) Directional chevrons flowing down every lane (sense of a runway).
    _drawChevrons(canvas, size);

    // 2) Lane dividers — thin dashed cyan.
    final dashPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.45)
      ..strokeWidth = 2.5;
    for (var i = 1; i < e.lanes; i++) {
      final x = i * e.laneW;
      const dash = 44.0, gap = 36.0;
      final period = dash + gap;
      var y = (e.distancePx % period) - period;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dash), dashPaint);
        y += period;
      }
    }

    // 3) Bright energy rails around the player's current lane.
    final lx = e.laneCenterX(e.playerLane);
    final left = lx - e.laneW / 2;
    final right = lx + e.laneW / 2;
    final pulse = 0.5 + 0.5 * sin(e.distancePx * 0.03);
    final railFill = Paint()
      ..shader = null
      ..color = AppColors.cyan.withValues(alpha: 0.04 + 0.03 * pulse);
    canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), railFill);
    final rail = Paint()
      ..strokeWidth = 3
      ..color = AppColors.cyan.withValues(alpha: 0.55 + 0.25 * pulse);
    final railGlow = Paint()
      ..strokeWidth = 8
      ..color = AppColors.cyan.withValues(alpha: 0.12);
    for (final rx in [left, right]) {
      canvas.drawLine(Offset(rx, 0), Offset(rx, size.height), railGlow);
      canvas.drawLine(Offset(rx, 0), Offset(rx, size.height), rail);
    }

    // 4) Warp speed streaks across the whole road.
    _drawSpeedLines(canvas, size, intensity);

    // 5) On turbo, darken the screen edges for a tunnel-vision rush.
    if (turbo) {
      final w = size.width * 0.16;
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, size.height),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x99040310), Colors.transparent],
            ).createShader(Rect.fromLTWH(0, 0, w, size.height)));
      canvas.drawRect(
          Rect.fromLTWH(size.width - w, 0, w, size.height),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0x99040310), Colors.transparent],
            ).createShader(Rect.fromLTWH(size.width - w, 0, w, size.height)));
    }
  }

  /// Free-flight / duel arena. No lanes, so the floor reads as open airspace:
  /// a scrolling horizon grid between two hard corridor rails.
  void _drawCorridor(Canvas canvas, Size size) {
    final boss = e.mode == GameMode.boss;

    // Scrolling horizon lines.
    const spacing = 86.0;
    final off = e.distancePx % spacing;
    final line = Paint()..strokeWidth = 1.4;
    for (double y = off - spacing; y < size.height; y += spacing) {
      final depth = (y / size.height).clamp(0.0, 1.0);
      line.color = (boss ? AppColors.danger : AppColors.blue)
          .withValues(alpha: 0.05 + 0.10 * depth);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Perspective verticals converging on the vanishing point.
    final vp = Offset(size.width / 2, size.height * 0.06);
    final rays = Paint()
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i <= 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(vp, Offset(x, size.height), rays);
    }

    // Corridor rails — the hard limits of the play field.
    final railColor = boss ? AppColors.danger : AppColors.magenta;
    final pulse = 0.5 + 0.5 * sin(e.distancePx * 0.04);
    final rail = Paint()
      ..strokeWidth = 3
      ..color = railColor.withValues(alpha: 0.4 + 0.25 * pulse);
    canvas.drawLine(const Offset(2, 0), Offset(2, size.height), rail);
    canvas.drawLine(
        Offset(size.width - 2, 0), Offset(size.width - 2, size.height), rail);

    if (!boss) {
      // Altitude / throttle ladder: high is fast, low is safe.
      final top = size.height * 0.28;
      final bottom = size.height * 0.92;
      const lx = 12.0;
      canvas.drawLine(Offset(lx, top), Offset(lx, bottom),
          Paint()..strokeWidth = 2..color = Colors.white.withValues(alpha: 0.10));
      for (var i = 0; i <= 4; i++) {
        final y = top + (bottom - top) * i / 4;
        canvas.drawLine(
            Offset(lx - 4, y),
            Offset(lx + 4, y),
            Paint()
              ..strokeWidth = 1.6
              ..color = Colors.white.withValues(alpha: 0.12));
      }
      final marker = e.playerBaseY.clamp(top, bottom);
      canvas.drawCircle(Offset(lx, marker), 4.5,
          Paint()..color = AppColors.cyan.withValues(alpha: 0.9));
    }

    _drawSpeedLines(
        canvas, size, e.turboActive ? 1.0 : (boss ? 0.3 : 0.55));
  }

  /// The gunship duel: telegraphed danger first, then the machine itself.
  void _drawBoss(Canvas canvas, Size size) {
    if (e.mode != GameMode.boss || e.bossHp <= 0) return;

    // Attack warnings — the whole fight is readable before it lands.
    if (e.telegraphX.isNotEmpty && e.bossState == 'telegraph') {
      final blink = 0.45 + 0.55 * (0.5 + 0.5 * sin(e.elapsed * 26));
      for (final x in e.telegraphX) {
        final w = e.bossAttack == 2 ? 10.0 : e.laneW * 0.55;
        final r = Rect.fromLTWH(x - w / 2, 0, w, size.height);
        canvas.drawRect(
            r,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.danger.withValues(alpha: 0.30 * blink),
                  AppColors.danger.withValues(alpha: 0.04 * blink),
                ],
              ).createShader(r));
        canvas.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = AppColors.danger.withValues(alpha: 0.55 * blink));
      }
    }

    // Sweeping beam.
    if (e.sweepActive) {
      final w = e.laneW * 0.84;
      final r = Rect.fromLTWH(e.sweepX - w / 2, 0, w, size.height);
      canvas.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                AppColors.danger.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ).createShader(r));
      canvas.drawLine(
          Offset(e.sweepX, 0),
          Offset(e.sweepX, size.height),
          Paint()
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: 0.8));
    }

    // Hull.
    final cx = e.bossX;
    final cy = e.bossY;
    final w = e.laneW * 2.1;
    final h = e.laneW * 0.95;
    final hurt = e.bossHitFlash.clamp(0.0, 1.0);
    final accent = Color.lerp(
        e.bossPhase == 3 ? AppColors.gold : AppColors.danger,
        Colors.white,
        hurt)!;

    final body = Path()
      ..moveTo(cx, cy + h * 0.55)
      ..lineTo(cx - w * 0.5, cy + h * 0.05)
      ..lineTo(cx - w * 0.34, cy - h * 0.45)
      ..lineTo(cx + w * 0.34, cy - h * 0.45)
      ..lineTo(cx + w * 0.5, cy + h * 0.05)
      ..close();
    canvas.drawPath(
        body, Paint()..color = Color.lerp(const Color(0xF01A0512), Colors.white, hurt * 0.5)!);
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = accent);

    // Wing pods, one per remaining phase.
    for (var i = 0; i < e.bossPhase; i++) {
      final t = e.bossPhase == 1 ? 0.0 : (i / (e.bossPhase - 1)) * 2 - 1;
      canvas.drawCircle(
          Offset(cx + t * w * 0.34, cy + h * 0.1),
          h * 0.11,
          Paint()..color = accent.withValues(alpha: 0.85));
    }

    // Scanning eye.
    final eye = 0.5 + 0.5 * sin(e.elapsed * 5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy - h * 0.16),
                width: w * 0.44,
                height: h * 0.2),
            const Radius.circular(6)),
        Paint()..color = accent.withValues(alpha: 0.35 + 0.45 * eye));

    // Armour segments left, mirroring hit points.
    final segs = 8;
    final segW = w * 0.9 / segs;
    for (var i = 0; i < segs; i++) {
      final filled = (i + 1) / segs <= e.bossHp;
      canvas.drawRect(
          Rect.fromLTWH(cx - w * 0.45 + i * segW + 1, cy + h * 0.28,
              segW - 2, 4),
          Paint()
            ..color = filled
                ? accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.12));
    }

    // Targeting line once the cannon is loaded.
    if (e.charge >= 1) {
      final p = Paint()
        ..strokeWidth = 1.6
        ..color = AppColors.cyan.withValues(alpha: 0.35);
      var y = e.playerDrawY - e.laneW * 0.6;
      while (y > cy + h * 0.4) {
        canvas.drawLine(Offset(e.playerX, y), Offset(e.playerX, y - 10), p);
        y -= 22;
      }
    }
  }

  void _drawChevrons(Canvas canvas, Size size) {
    const spacing = 150.0;
    final scroll = e.distancePx % spacing;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.cyan.withValues(alpha: 0.14);
    final w = e.laneW * 0.24;
    const h = 20.0;
    for (var lane = 0; lane < e.lanes; lane++) {
      final cx = e.laneCenterX(lane);
      for (double y = scroll - spacing; y < size.height + h; y += spacing) {
        final path = Path()
          ..moveTo(cx - w, y + h)
          ..lineTo(cx, y)
          ..lineTo(cx + w, y + h);
        canvas.drawPath(path, p);
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size, double intensity) {
    final rnd = Random(9173);
    const n = 16;
    final scroll = e.distancePx * 1.6;
    final p = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * size.width;
      final len = 26 + rnd.nextDouble() * 70;
      final spd = 0.85 + rnd.nextDouble() * 0.7;
      final jitter = rnd.nextDouble();
      final period = size.height + len + 120;
      final y = ((scroll * spd + jitter * period) % period) - len;
      p
        ..color = Colors.white.withValues(alpha: (0.05 + 0.14 * intensity))
        ..strokeWidth = 1 + rnd.nextDouble() * (1.5 + intensity);
      canvas.drawLine(Offset(x, y), Offset(x, y + len), p);
    }
  }

  void _drawEntities(Canvas canvas, Size size) {
    for (final ent in e.entities) {
      if (ent.used && ent.kind != EntityKind.gate) continue;
      final cx = e.entX(ent);
      switch (ent.kind) {
        case EntityKind.sphere:
          final pulse = 1 + 0.08 * sin(ent.phase * 6);
          _sprite(canvas, Sprites.spheres, e.sphereSprite, Offset(cx, ent.y),
              ent.size * pulse, ent.size * pulse);
          break;
        case EntityKind.crystal:
          final pulse = 1 + 0.06 * sin(ent.phase * 5);
          _sprite(canvas, Sprites.crystals, ent.sprite % 12,
              Offset(cx, ent.y - sin(ent.phase * 3) * 4), ent.size * pulse,
              ent.size * pulse);
          break;
        case EntityKind.boost:
          _sprite(canvas, Sprites.boostPads, ent.sprite % 24, Offset(cx, ent.y),
              ent.size * 1.2, ent.size * 0.9);
          break;
        case EntityKind.ramp:
          _sprite(canvas, Sprites.ramps, ent.sprite % 10, Offset(cx, ent.y),
              ent.size, ent.size);
          break;
        case EntityKind.gate:
          _sprite(canvas, Sprites.gates, ent.sprite % 21,
              Offset(size.width / 2, ent.y), size.width * 0.8, e.laneW * 1.6);
          break;
        case EntityKind.police:
          if (ent.chase) {
            // Warning marker under a hunting cop.
            final blink = 0.5 + 0.5 * sin(ent.phase * 12);
            canvas.drawCircle(
                Offset(cx, ent.y),
                ent.size * 0.62,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = AppColors.danger.withValues(alpha: 0.4 + 0.4 * blink));
          }
          _sprite(canvas, Sprites.police, _policeCarCells[ent.sprite % 4],
              Offset(cx, ent.y), ent.size, ent.size * 1.15, quarter: 2);
          break;
        case EntityKind.barrier:
          _barrier(canvas, Offset(cx, ent.y), ent.size);
          break;
        case EntityKind.shieldPU:
          _powerToken(canvas, Offset(cx, ent.y), ent.size, AppColors.cyan,
              ent.phase, shield: true);
          break;
        case EntityKind.magnetPU:
          _powerToken(canvas, Offset(cx, ent.y), ent.size, AppColors.magenta,
              ent.phase, shield: false);
          break;
        case EntityKind.wall:
          _wall(canvas, Offset(cx, ent.y), ent.w, ent.size);
          break;
        case EntityKind.ring:
          _ring(canvas, Offset(cx, ent.y), ent.size, ent.phase);
          break;
        case EntityKind.bomb:
          _bomb(canvas, Offset(cx, ent.y), ent.size, ent.phase);
          break;
        case EntityKind.bolt:
          _bolt(canvas, Offset(cx, ent.y), ent.size);
          break;
      }
    }
  }

  /// A solid slab. The only safe route is the gap beside it.
  void _wall(Canvas canvas, Offset c, double w, double h) {
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = const Color(0xF00E0C1A));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.danger.withValues(alpha: 0.9));
    canvas.save();
    canvas.clipRRect(rr);
    final hatch = Paint()
      ..strokeWidth = 5
      ..color = AppColors.danger.withValues(alpha: 0.28);
    for (double x = rect.left - h; x < rect.right; x += 20) {
      canvas.drawLine(
          Offset(x, rect.bottom), Offset(x + h, rect.top), hatch);
    }
    canvas.restore();
    // Bright lip on the gap-facing edges.
    final lip = Paint()
      ..strokeWidth = 3
      ..color = AppColors.gold;
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.bottom), lip);
    canvas.drawLine(
        Offset(rect.right, rect.top), Offset(rect.right, rect.bottom), lip);
  }

  void _ring(Canvas canvas, Offset c, double s, double phase) {
    final r = s * 0.5;
    final pulse = 0.5 + 0.5 * sin(phase * 4);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: s, height: s * 0.42),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = AppColors.blue.withValues(alpha: 0.55 + 0.25 * pulse));
    canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.35));
    // Centre pip marks the perfect line.
    canvas.drawCircle(
        c,
        r * 0.1,
        Paint()..color = AppColors.gold.withValues(alpha: 0.5 + 0.4 * pulse));
  }

  void _bomb(Canvas canvas, Offset c, double s, double phase) {
    final r = s * 0.5;
    final pulse = 0.5 + 0.5 * sin(phase * 12);
    canvas.drawCircle(
        c, r * (1.25 + 0.12 * pulse),
        Paint()..color = AppColors.danger.withValues(alpha: 0.16));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xEE1A0410));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = AppColors.danger.withValues(alpha: 0.7 + 0.3 * pulse));
    final spike = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.danger;
    for (var i = 0; i < 4; i++) {
      final a = phase * 2 + i * pi / 2;
      canvas.drawLine(
          Offset(c.dx + cos(a) * r * 0.55, c.dy + sin(a) * r * 0.55),
          Offset(c.dx + cos(a) * r * 1.25, c.dy + sin(a) * r * 1.25),
          spike);
    }
  }

  void _bolt(Canvas canvas, Offset c, double s) {
    final rect = Rect.fromCenter(center: c, width: s * 0.5, height: s * 2.2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.25)),
        Paint()..color = AppColors.cyan);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(s * 0.25), Radius.circular(s * 0.4)),
        Paint()..color = AppColors.cyan.withValues(alpha: 0.22));
  }

  void _powerToken(Canvas canvas, Offset c, double s, Color color, double phase,
      {required bool shield}) {
    final r = s * 0.5;
    final pulse = 1 + 0.08 * sin(phase * 6);
    // Disc backing.
    canvas.drawCircle(
        c, r * pulse, Paint()..color = const Color(0xEE0A0918));
    canvas.drawCircle(
        c,
        r * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color);
    final icon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (shield) {
      // Shield outline.
      final p = Path()
        ..moveTo(c.dx, c.dy - r * 0.5)
        ..lineTo(c.dx + r * 0.42, c.dy - r * 0.2)
        ..lineTo(c.dx + r * 0.42, c.dy + r * 0.15)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.6, c.dx - r * 0.42, c.dy + r * 0.15)
        ..lineTo(c.dx - r * 0.42, c.dy - r * 0.2)
        ..close();
      canvas.drawPath(p, icon..style = PaintingStyle.stroke);
    } else {
      // Magnet horseshoe.
      final rect = Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * 0.05),
          width: r * 0.8,
          height: r * 0.8);
      canvas.drawArc(rect, pi, pi, false, icon);
      canvas.drawLine(Offset(c.dx - r * 0.4, c.dy - r * 0.05),
          Offset(c.dx - r * 0.4, c.dy + r * 0.4), icon);
      canvas.drawLine(Offset(c.dx + r * 0.4, c.dy - r * 0.05),
          Offset(c.dx + r * 0.4, c.dy + r * 0.4), icon);
    }
  }

  void _barrier(Canvas canvas, Offset c, double s) {
    final rect = Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.55);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF15131f));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.gold);
    canvas.save();
    canvas.clipRRect(rr);
    final p = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.9)
      ..strokeWidth = 6;
    for (double x = rect.left - rect.height; x < rect.right; x += 16) {
      canvas.drawLine(
          Offset(x, rect.bottom), Offset(x + rect.height, rect.top), p);
    }
    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final px = e.playerX;
    final py = e.playerDrawY;

    // Hover shadow on the ground.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(px, e.playerBaseY + e.laneW * 0.5),
            width: e.laneW * 0.72,
            height: e.laneW * 0.22),
        _tmp..color = Colors.black.withValues(alpha: 0.32)..shader = null);

    // Trail behind the board (below, plume pointing down).
    if (e.started) {
      final tOpacity = e.turboActive ? 1.0 : (e.drifting ? 0.9 : 0.7);
      _sprite(canvas, Sprites.trails, e.trailSprite,
          Offset(px, py + e.laneW * 0.9), e.laneW * 0.7, e.laneW * 1.8,
          opacity: tOpacity);
    }


    // Magnet field ring around the board.
    if (e.magnetActive) {
      final mp = 0.5 + 0.5 * sin(e.distancePx * 0.05);
      canvas.drawCircle(
          Offset(px, py),
          e.laneW * (0.7 + 0.08 * mp),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.magenta.withValues(alpha: 0.25 + 0.2 * mp));
    }

    // Board (upright, small lane-switch tilt, spins during a trick).
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(e.tilt * 0.5 + (e.spinning ? e.spinAngle : 0));
    _spriteAt(canvas, Sprites.boards, e.boardSprite, Offset.zero,
        e.laneW * 0.82, e.laneW * 1.3);
    canvas.restore();

    // Shield bubble.
    if (e.shield || e.shieldFlash > 0) {
      final a = e.shield ? 0.35 : e.shieldFlash * 0.6;
      final sp = 0.5 + 0.5 * sin(e.distancePx * 0.06);
      canvas.drawCircle(
          Offset(px, py),
          e.laneW * (0.62 + 0.05 * sp),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = AppColors.cyan.withValues(alpha: (a + 0.15 * sp).clamp(0.0, 0.9)));
    }

    // Cargo sphere floats above the board with a gentle bob.
    final bob = sin(e.distancePx * 0.02) * 3;
    final cargoY = py - e.laneW * 0.55 + bob;
    final cargoSize = e.laneW * 0.42;
    _spriteAt(canvas, Sprites.spheres, e.sphereSprite,
        Offset(px, cargoY), cargoSize, cargoSize);

    // Loaded cannon ring in the duel.
    if (e.mode == GameMode.boss && e.charge >= 1) {
      final cp = 0.5 + 0.5 * sin(e.elapsed * 9);
      canvas.drawCircle(
          Offset(px, py),
          e.laneW * (0.55 + 0.05 * cp),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = AppColors.cyan.withValues(alpha: 0.5 + 0.4 * cp));
    }
  }

  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in e.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final c = _particleColors[p.colorIndex % _particleColors.length];
      final pos = Offset(p.x, p.y);
      paint.color = c.withValues(alpha: t * 0.35);
      canvas.drawCircle(pos, p.size * t * 1.8, paint);
      paint.color = c.withValues(alpha: t * 0.85);
      canvas.drawCircle(pos, p.size * t, paint);
    }
  }

  // ---- sprite helpers ----------------------------------------------------
  void _sprite(Canvas canvas, SheetSpec spec, int index, Offset center,
      double boxW, double boxH,
      {int quarter = 0, double opacity = 1}) {
    _spriteAt(canvas, spec, index, center, boxW, boxH,
        quarter: quarter, opacity: opacity);
  }

  void _spriteAt(Canvas canvas, SheetSpec spec, int index, Offset center,
      double boxW, double boxH,
      {int quarter = 0, double opacity = 1}) {
    final img = Sprites.I.img(spec.key);
    if (img == null) return;
    final src = spec.cell(index, img);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (quarter != 0) canvas.rotate(quarter * pi / 2);
    final box = quarter.isOdd ? Size(boxH, boxW) : Size(boxW, boxH);
    final fitted = applyBoxFit(BoxFit.contain, src.size, box);
    final dst = Rect.fromCenter(
        center: Offset.zero,
        width: fitted.destination.width,
        height: fitted.destination.height);
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Colors.white.withValues(alpha: opacity);
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
