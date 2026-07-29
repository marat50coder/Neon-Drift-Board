import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/levels.dart';
import '../game/engine.dart';
import '../game/game_painter.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'results_screen.dart';

class GameScreen extends StatefulWidget {
  final ContractType contract;
  final GameMode mode;
  final LevelDef? level;
  const GameScreen({
    super.key,
    required this.contract,
    this.mode = GameMode.campaign,
    this.level,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final GameEngine _engine;
  Duration _last = Duration.zero;
  bool _recorded = false;

  // Unified pan gesture state — avoids gesture-arena delays.
  Offset _panCumul = Offset.zero;
  bool _panMoved = false;
  bool _panDrifting = false;
  Timer? _driftTimer;
  // Cooldown so one swipe never skips more than one lane at a time.
  bool _laneCooldown = false;
  Timer? _laneCooldownTimer;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameState>();
    // Campaign levels carry their own backdrop; free-play uses the district
    // the player has selected and unlocked.
    final level = widget.level;
    final district = level != null
        ? Catalog.districts.firstWhere((d) => d.index == level.districtIndex,
            orElse: () => Catalog.districts.first)
        : Catalog.districts.firstWhere((d) => d.id == gs.district,
            orElse: () => Catalog.districts.first);
    _engine = GameEngine(
      contract: widget.contract,
      district: district,
      // Campaign levels carry their own rule set, so the same screen can host
      // a lane run, a free-flight leg or a duel.
      boardSprite: Catalog.boardById(gs.board).spriteIndex,
      sphereSprite: Catalog.sphereById(gs.sphere).spriteIndex,
      trailSprite: Catalog.trailById(gs.trail).spriteIndex,
      turboSprite: Catalog.turboById(gs.turbo).spriteIndex,
      showFx: gs.showFx,
      onSound: (s) => Audio.I.play(s),
      mode: level?.mode ?? widget.mode,
      level: level,
      upgrades: gs.upgradeStats,
    );
    Audio.I.startGameMusic();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.016
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _engine.update(dt);
    if (_engine.finished && _engine.result != null && !_recorded) {
      _recorded = true;
      _finish();
    }
  }

  void _finish() {
    _ticker.stop();
    final gs = context.read<GameState>();
    final result = _engine.result!;
    gs.recordRun(result);
    Audio.I.stopMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ResultsScreen(result: result)));
    });
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    _laneCooldownTimer?.cancel();
    _ticker.dispose();
    Audio.I.stopMusic();
    super.dispose();
  }

  // ---- Unified pan gesture -----------------------------------------------
  // Single recognizer means no arena delay — everything responds immediately.

  void _panStart(DragStartDetails _) {
    _panCumul = Offset.zero;
    _panMoved = false;
    _panDrifting = false;
    _driftTimer?.cancel();
    // Free flight steers directly — there is no drift to hold for.
    if (_engine.freeControl) return;
    // Hold still for 190ms → drift.
    _driftTimer = Timer(const Duration(milliseconds: 190), () {
      if (!_panMoved && !_engine.finished && _engine.started) {
        _panDrifting = true;
        _engine.setDrift(true);
      }
    });
  }

  void _panUpdate(DragUpdateDetails d) {
    // Free flight: the finger is a stick, every pixel of it counts.
    if (_engine.freeControl) {
      _engine.steer(d.delta.dx, d.delta.dy);
      _panCumul += d.delta;
      if (_panCumul.distance > 16) _panMoved = true;
      return;
    }
    if (_panDrifting) return;
    _panCumul += d.delta;
    // Trigger lane change as soon as horizontal threshold crossed — but only
    // once per cooldown window so a single swipe never skips a lane.
    const kLane = 28.0;
    if (!_laneCooldown &&
        _panCumul.dx.abs() > kLane &&
        _panCumul.dx.abs() > _panCumul.dy.abs() * 0.9) {
      _panMoved = true;
      _driftTimer?.cancel();
      if (_panCumul.dx < 0) {
        _engine.moveLeft();
      } else {
        _engine.moveRight();
      }
      _panCumul = Offset.zero;
      // Block further lane changes for 220 ms so one swipe = one lane.
      _laneCooldown = true;
      _laneCooldownTimer?.cancel();
      _laneCooldownTimer = Timer(const Duration(milliseconds: 220), () {
        _laneCooldown = false;
      });
    }
  }

  void _panEnd(DragEndDetails d) {
    _driftTimer?.cancel();
    if (_panDrifting) {
      _panDrifting = false;
      _engine.setDrift(false);
      return;
    }
    // Tap = end with no movement → mode's primary action.
    if (!_panMoved) {
      _engine.primaryAction();
    }
    // Fast upward flick → turbo (lane modes only; flight uses up for altitude).
    if (!_engine.freeControl && d.velocity.pixelsPerSecond.dy < -700) {
      _engine.activateTurbo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: GamePainter(_engine)),
          ),
          // Single pan recognizer — zero arena delay.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
          ),
          RepaintBoundary(child: _Hud(engine: _engine)),
          if (gs.controlMode == 'buttons' && !_engine.freeControl)
            _buttonControls(),
          if (_engine.freeControl) _actionButton(),
          _turboButton(),
          _CountdownOverlay(engine: _engine),
          _PauseOverlay(engine: _engine, onQuit: _quit, onRestart: _restart),
        ],
      ),
    );
  }

  void _quit() {
    Audio.I.stopMusic();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _restart() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(
              contract: widget.contract,
              mode: widget.mode,
              level: widget.level,
            )));
  }

  Widget _turboButton() {
    return Positioned(
      right: 20,
      bottom: 22,
      child: AnimatedBuilder(
        animation: _engine,
        builder: (_, _) {
          final energy = _engine.turbo;
          final ready = energy >= 0.3;
          return GestureDetector(
            onTap: _engine.activateTurbo,
            child: SizedBox(
              width: 74,
              height: 74,
              child: CustomPaint(
                painter: _TurboArcPainter(energy: energy, ready: ready),
                child: Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    color: ready ? AppColors.cyan : Colors.white30,
                    size: 32,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Free-flight modes replace the lane pad with their own single verb:
  /// the cannon in the duel, the barrel roll in flight.
  Widget _actionButton() {
    final boss = _engine.mode == GameMode.boss;
    return Positioned(
      left: 20,
      bottom: 22,
      child: AnimatedBuilder(
        animation: _engine,
        builder: (_, _) {
          final value = boss
              ? _engine.charge
              : 1 - (_engine.rollCd / GameEngine.rollCdMax);
          final ready = value >= 1;
          final color = boss ? AppColors.gold : AppColors.magenta;
          return GestureDetector(
            onTap: boss ? _engine.fire : _engine.barrelRoll,
            child: SizedBox(
              width: 78,
              height: 78,
              child: CustomPaint(
                painter: _TurboArcPainter(
                    energy: value.clamp(0.0, 1.0), ready: ready, color: color),
                child: Center(
                  child: Icon(
                    boss ? Icons.gps_fixed_rounded : Icons.threesixty_rounded,
                    color: ready ? color : Colors.white30,
                    size: 34,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buttonControls() {
    Widget b(IconData ic, VoidCallback f) => GestureDetector(
          onTap: f,
          child: Container(
            width: 62,
            height: 62,
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.5)),
            ),
            child: Icon(ic, color: AppColors.cyan, size: 30),
          ),
        );
    return Positioned(
      left: 18,
      bottom: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          b(Icons.keyboard_arrow_left_rounded, _engine.moveLeft),
          b(Icons.keyboard_arrow_right_rounded, _engine.moveRight),
          const SizedBox(width: 6),
          b(Icons.keyboard_double_arrow_up_rounded, _engine.jump),
        ],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final GameEngine engine;
  const _Hud({required this.engine});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: engine,
        builder: (_, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pause (interactive).
                    NeonIconButton(
                      icon: engine.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 40,
                      onTap: engine.togglePause,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _routeBar()),
                    const SizedBox(width: 12),
                    IgnorePointer(child: _hearts()),
                  ],
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        engine.score.toString().padLeft(5, '0'),
                        style: const TextStyle(
                          fontFamily: AppText.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: AppColors.cyan, blurRadius: 14)
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (engine.combo > 1) _comboChip(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IgnorePointer(child: _overdriveBar()),
                const SizedBox(height: 6),
                IgnorePointer(child: _powerChips()),
                const SizedBox(height: 6),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _objectives(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overdriveBar() {
    // In the duel the meter that matters is the cannon, not overdrive.
    if (engine.mode == GameMode.boss) {
      final ready = engine.charge >= 1;
      return Center(
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ready ? 'CANNON READY — TAP' : 'CANNON ${(engine.charge * 100).round()}%',
                style: TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: ready ? AppColors.gold : AppColors.textMid,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: engine.charge,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation(
                      ready ? AppColors.gold : AppColors.cyan),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final active = engine.overdriveActive;
    return Center(
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active ? 'OVERDRIVE' : 'OVERDRIVE ${(engine.overdrive * 100).round()}%',
              style: TextStyle(
                fontFamily: AppText.display,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.5,
                color: active ? AppColors.gold : AppColors.textMid,
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: engine.overdrive,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(
                    active ? AppColors.gold : AppColors.magenta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _powerChips() {
    final chips = <Widget>[];
    if (engine.shield) {
      chips.add(_powerChip(Icons.shield_rounded, 'SHIELD', AppColors.cyan));
    }
    if (engine.magnetActive) {
      chips.add(_powerChip(Icons.settings_input_antenna_rounded,
          '${engine.magnetTime.ceil()}s', AppColors.magenta));
    }
    if (chips.isEmpty) return const SizedBox(height: 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in chips)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c),
      ],
    );
  }

  Widget _powerChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color)),
        ],
      ),
    );
  }

  /// Each mode headlines a different resource, so the top gauge changes with it.
  Widget _routeBar() {
    late final IconData icon;
    late final String left;
    late final String right;
    late final double value;
    late final Color color;

    switch (engine.mode) {
      case GameMode.timeAttack:
        icon = Icons.timer_rounded;
        value = (engine.timeLeft / 90).clamp(0.0, 1.0);
        left = 'TIME ${engine.timeLeft.ceil()}s';
        right = '${engine.meters.round()} m';
        color = engine.timeLeft < 15 ? AppColors.danger : AppColors.gold;
        break;
      case GameMode.pursuit:
        icon = Icons.radar_rounded;
        value = (engine.hunterGap / GameEngine.hunterMaxGap).clamp(0.0, 1.0);
        left = 'HUNTER ${(value * 100).round()}%';
        right = '${engine.meters.round()} / ${engine.routeTargetMeters.round()} m';
        color = value < 0.3 ? AppColors.danger : AppColors.magenta;
        break;
      case GameMode.endless:
        icon = Icons.all_inclusive_rounded;
        value = (engine.meters % 500) / 500;
        left = 'SURVIVAL ${engine.elapsed.round()}s';
        right = '${engine.meters.round()} m';
        color = AppColors.magenta;
        break;
      case GameMode.precision:
        icon = Icons.flag_circle_rounded;
        value = engine.progress;
        left = 'CHAIN x${engine.chain}';
        right = '${engine.meters.round()} m';
        color = AppColors.green;
        break;
      case GameMode.flight:
        icon = Icons.open_with_rounded;
        value = engine.progress;
        left = 'FLIGHT ${(engine.progress * 100).round()}%';
        right = '${engine.rings} rings';
        color = AppColors.blue;
        break;
      case GameMode.boss:
        icon = Icons.smart_toy_rounded;
        value = engine.bossHp;
        left = 'GUNSHIP ${(engine.bossHp * 100).round()}%';
        right = 'PHASE ${engine.bossPhase}';
        color = engine.bossPhase == 3 ? AppColors.gold : AppColors.danger;
        break;
      case GameMode.campaign:
        icon = Icons.route_rounded;
        value = engine.progress;
        left = 'ROUTE ${(engine.progress * 100).round()}%';
        right = '${engine.meters.round()} m';
        color = AppColors.cyan;
        break;
    }

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(left,
                  style: TextStyle(
                      fontFamily: AppText.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: color)),
              const Spacer(),
              Flexible(
                child: Text(right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: AppText.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textMid)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  /// Live objective tracker for campaign levels.
  Widget _objectives() {
    final level = engine.level;
    if (level == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in level.objectives)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  engine.objectiveMet(o)
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 13,
                  color: engine.objectiveMet(o)
                      ? AppColors.green
                      : AppColors.textLow,
                ),
                const SizedBox(width: 5),
                Text(
                  o.type == ObjectiveType.noCrash
                      ? 'No crash'
                      : '${engine.objectiveProgress(o).clamp(0, o.target)}/${o.target} ${_objShort(o.type)}',
                  style: TextStyle(
                    fontFamily: AppText.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: engine.objectiveMet(o)
                        ? AppColors.green
                        : AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _objShort(ObjectiveType t) {
    switch (t) {
      case ObjectiveType.spheres:
        return 'spheres';
      case ObjectiveType.crystals:
        return 'crystals';
      case ObjectiveType.grazes:
        return 'grazes';
      case ObjectiveType.tricks:
        return 'tricks';
      case ObjectiveType.drifts:
        return 'drifts';
      case ObjectiveType.turbos:
        return 'turbos';
      case ObjectiveType.score:
        return 'pts';
      case ObjectiveType.combo:
        return 'combo';
      case ObjectiveType.noCrash:
        return '';
      case ObjectiveType.rings:
        return 'rings';
      case ObjectiveType.chain:
        return 'chain';
    }
  }

  Widget _hearts() {
    // Time Attack has no hull — crashes cost seconds instead.
    if (engine.mode == GameMode.timeAttack) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 4),
          Text('${engine.timeLeft.ceil()}',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        engine.maxIntegrity,
        (i) => Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Icon(
            i < engine.integrity
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: i < engine.integrity ? AppColors.danger : Colors.white24,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// The chip carries its own countdown, because the combo now decays when the
  /// player stops scoring and that has to be visible.
  Widget _comboChip() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: AppColors.magentaGradient),
          ),
          child: Text('x${engine.combo}',
              style: const TextStyle(
                  fontFamily: AppText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 42,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: engine.comboFrac,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(
                  engine.comboFrac < 0.3 ? AppColors.danger : AppColors.magenta),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final GameEngine engine;
  const _CountdownOverlay({required this.engine});

  static String _hint(GameMode mode) {
    switch (mode) {
      case GameMode.flight:
        return 'DRAG anywhere to fly — the board has real momentum\n'
            'FLY HIGH for speed, LOW for reaction time\n'
            'TAP / ⟳ barrel roll dodges anything for a moment';
      case GameMode.boss:
        return 'DRAG anywhere to fly freely around the arena\n'
            'COLLECT spheres to charge the cannon, TAP to fire\n'
            'RED columns and beams are telegraphed — read them and move';
      default:
        return 'SWIPE ←  → lanes  •  TAP jump  •  TAP again mid-air = TRICK\n'
            'HOLD drift  •  SWIPE ↑ / ⚡ turbo  •  graze cops & fill OVERDRIVE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (_, _) {
        if (engine.started) return const SizedBox.shrink();
        final n = engine.countdown.ceil();
        final label = n <= 0 ? 'GO' : '$n';
        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GET READY',
                    style: TextStyle(
                        fontFamily: AppText.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 3,
                        color: AppColors.textMid)),
                Text(label,
                    style: const TextStyle(
                        fontFamily: AppText.display,
                        fontWeight: FontWeight.w900,
                        fontSize: 92,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: AppColors.cyan, blurRadius: 30),
                          Shadow(color: AppColors.magenta, blurRadius: 40),
                        ])),
                Text(_hint(engine.mode),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppText.body,
                        fontSize: 13,
                        color: AppColors.textMid)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final GameEngine engine;
  final VoidCallback onQuit;
  final VoidCallback onRestart;
  const _PauseOverlay(
      {required this.engine, required this.onQuit, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (_, _) {
        if (!engine.paused || engine.finished) return const SizedBox.shrink();
        return Container(
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PAUSED',
                  style: TextStyle(
                      fontFamily: AppText.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                      color: Colors.white,
                      letterSpacing: 3)),
              const SizedBox(height: 22),
              NeonButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  onTap: engine.togglePause),
              const SizedBox(height: 12),
              GhostButton(
                  label: 'Restart',
                  icon: Icons.refresh_rounded,
                  onTap: onRestart),
              const SizedBox(height: 12),
              GhostButton(
                  label: 'Quit',
                  icon: Icons.close_rounded,
                  color: AppColors.danger,
                  onTap: onQuit),
            ],
          ),
        );
      },
    );
  }
}

// Lightweight arc ring for the turbo gauge — no shader, no boxShadow.
class _TurboArcPainter extends CustomPainter {
  final double energy;
  final bool ready;
  final Color color;
  const _TurboArcPainter({
    required this.energy,
    required this.ready,
    this.color = AppColors.cyan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.drawCircle(c, r - 4, Paint()..color = const Color(0xCC070615));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white12);

    if (energy > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,
        energy * 2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = ready ? color : color.withValues(alpha: 0.5),
      );
    }

    if (ready) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(covariant _TurboArcPainter old) =>
      old.energy != energy || old.ready != ready || old.color != color;
}
