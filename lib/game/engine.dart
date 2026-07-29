import 'dart:math';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../data/levels.dart';
import '../data/models.dart';
import '../data/upgrades.dart';

enum EntityKind {
  sphere,
  crystal,
  police,
  barrier,
  boost,
  ramp,
  gate,
  shieldPU,
  magnetPU,

  /// Free-flight only: a solid slab spanning part of the width. Cannot be
  /// jumped — the only way past is through the gap.
  wall,

  /// Free-flight only: a bonus hoop scored by flying through its centre.
  ring,

  /// Hostile projectile with its own velocity (boss attacks, drifting mines).
  bomb,

  /// The player's cannon round travelling up toward the boss.
  bolt,
}

class Entity {
  EntityKind kind;
  double y; // position along the travel axis (top -> bottom)
  int lane; // column index
  int sprite;
  bool used = false;
  double size;
  double phase;
  double drift; // horizontal px offset from lane centre (AI / magnet pull)
  double aiTimer;
  bool chase; // police that hunts the player
  bool grazed;

  /// Absolute x in pixels. When set the entity ignores the lane grid — used by
  /// the free-movement modes where there are no lanes at all.
  double? ax;

  /// Explicit width, only meaningful for [EntityKind.wall].
  double w;

  /// Self-propelled velocity, on top of (or instead of) the world scroll.
  double vxOwn;
  double vyOwn;

  /// Whether the world scroll carries this entity down the screen.
  bool scrolls;

  Entity({
    required this.kind,
    required this.y,
    required this.lane,
    required this.sprite,
    required this.size,
    this.phase = 0,
    this.drift = 0,
    this.aiTimer = 0,
    this.chase = false,
    this.grazed = false,
    this.ax,
    this.w = 0,
    this.vxOwn = 0,
    this.vyOwn = 0,
    this.scrolls = true,
  });
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  int colorIndex;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size,
      this.colorIndex)
      : maxLife = life;
}

/// Floating score / event text (GRAZE, TRICK, OVERDRIVE ...).
class Floater {
  double x, y, life, maxLife;
  String text;
  int color; // 0 cyan, 1 gold, 2 magenta, 3 green, 4 white
  double scale;
  Floater(this.x, this.y, this.text, this.color, this.life, {this.scale = 1})
      : maxLife = life;
}

/// Frame-rate independent gameplay simulation for the vertical drift runner.
/// Forward is UP: the world scrolls downward while the player rides toward the
/// top of the screen, switching between vertical lanes (columns).
///
/// The same simulation backs five distinct rule sets (see [GameMode]) — the
/// win/lose condition, spawn table and scoring all branch on [mode].
class GameEngine extends ChangeNotifier {
  final Random _rng = Random();

  final ContractType contract;
  final District district;
  final int boardSprite;
  final int sphereSprite;
  final int trailSprite;
  final int turboSprite;
  final bool showFx;
  final void Function(String sound) onSound;

  final GameMode mode;
  final LevelDef? level;
  final UpgradeStats upgrades;

  GameEngine({
    required this.contract,
    required this.district,
    required this.boardSprite,
    required this.sphereSprite,
    required this.trailSprite,
    required this.turboSprite,
    required this.showFx,
    required this.onSound,
    this.mode = GameMode.campaign,
    this.level,
    this.upgrades = UpgradeStats.stock,
  }) {
    final baseHull = level?.hull ?? (contract.id == 'fragile' ? 1 : 3);
    maxIntegrity = baseHull + upgrades.bonusHull;
    integrity = maxIntegrity;
    routeTargetMeters = _routeTarget();
    turbo = upgrades.startTurbo;
    shield = upgrades.startShield;
  }

  double _routeTarget() {
    // Duels and timed levels have no finish line, level definition or not.
    if (mode == GameMode.boss || mode == GameMode.timeAttack) {
      return double.infinity;
    }
    if (level != null) return level!.targetMeters;
    switch (mode) {
      case GameMode.endless:
        return double.infinity;
      case GameMode.timeAttack:
        return double.infinity;
      case GameMode.pursuit:
        return 1500;
      case GameMode.precision:
        return 1050;
      case GameMode.flight:
        return 1200;
      case GameMode.boss:
        // The duel ends when the gunship does, not at a distance marker.
        return double.infinity;
      case GameMode.campaign:
        return _targetForContract();
    }
  }

  double _targetForContract() {
    switch (contract.id) {
      case 'vip':
        return 1350;
      case 'secret':
        return 1000;
      case 'storm':
        return 900;
      case 'overloaded':
        return 1050;
      case 'fragile':
        return 800;
      default:
        return 850;
    }
  }

  // Geometry (vertical)
  Size size = Size.zero;
  int lanes = 3;
  double laneW = 0;
  double playerY = 0;
  double laneAnim = 1;

  double laneCenterX(int lane) => (lane + 0.5) * laneW;
  double get playerX => freeControl ? freeX : (laneAnim + 0.5) * laneW;

  /// Resting height of the board — fixed in the lane modes, player-controlled
  /// in the free-movement modes.
  double get playerBaseY => freeControl ? freeY : playerY;
  double get playerDrawY => playerBaseY - jumpOffset;
  double entX(Entity e) => e.ax ?? (laneCenterX(e.lane) + e.drift);

  // ---- Free 2D flight ------------------------------------------------------
  /// Flight and Boss throw the lane grid away: the board is steered directly
  /// on both axes and carries real momentum.
  bool get freeControl => mode == GameMode.flight || mode == GameMode.boss;
  double freeX = 0;
  double freeY = 0;
  double freeVX = 0;
  double freeVY = 0;
  bool _freePlaced = false;

  double get _freeTopY => size.height * (mode == GameMode.boss ? 0.44 : 0.28);
  double get _freeBottomY => size.height * 0.92;

  /// Barrel roll — the free-flight dodge, on a cooldown so it can't be spammed.
  double rollCd = 0;
  static const double rollCdMax = 2.2;

  // Player
  int playerLane = 1;
  double jumpOffset = 0;
  double vy = 0;
  bool airborne = false;
  double tilt = 0;
  double invuln = 0;

  // Air trick
  bool spinning = false;
  double spinAngle = 0;

  // Motion
  double baseSpeed = 250;

  /// World speed for the current frame, in px/s. Spawn spacing is derived from
  /// it so the player always gets the same reaction *time*, not the same
  /// reaction *distance*, however fast the run gets.
  double _speed = 250;
  double boostTimer = 0;
  double distancePx = 0;
  double get meters => distancePx / 20.0;
  double routeTargetMeters = 950;
  double get progress => routeTargetMeters.isFinite
      ? (meters / routeTargetMeters).clamp(0.0, 1.0)
      : 0.0;

  // Turbo & drift
  double turbo = 0.35;
  bool turboActive = false;
  double turboTime = 0;
  bool drifting = false;
  double driftTime = 0;
  int drifts = 0;
  int turbos = 0;

  // Power-ups
  bool shield = false;
  double shieldFlash = 0;
  double magnetTime = 0;
  bool get magnetActive => magnetTime > 0;
  double get _magnetDuration => 6 + upgrades.magnetBonusSeconds;

  // Overdrive meter
  double overdrive = 0;
  double overdriveTime = 0;
  bool get overdriveActive => overdriveTime > 0;

  // ---- Mode specific -------------------------------------------------------
  /// Time Attack: seconds remaining on the clock.
  double timeLeft = 90;

  /// Pursuit: distance in pixels between the board and the hunter drone.
  double hunterGap = 380;
  static const double hunterMaxGap = 460;
  double hunterPhase = 0;
  bool caught = false;

  /// Precision: unbroken chain of collected spheres.
  int chain = 0;
  int bestChain = 0;

  /// Flight: hoops threaded, and how many of those were dead-centre.
  int rings = 0;
  int perfectRings = 0;

  // Boss duel.
  double bossHp = 1.0;
  double bossX = 0;
  double bossY = 0;
  int bossPhase = 1;
  double bossHitFlash = 0;

  /// Cannon charge, 0..1. Fires at full.
  double charge = 0;
  int bossHits = 0;

  /// 'idle' -> 'telegraph' -> 'attack'.
  String bossState = 'idle';
  double bossStateTimer = 1.8;
  int bossAttack = 0;

  /// Column centres currently flashing a warning.
  List<double> telegraphX = [];
  bool sweepActive = false;
  double sweepX = 0;
  double sweepDir = 1;

  double _elapsed = 0;
  double get elapsed => _elapsed;

  // Score
  double _scoreF = 0;
  int get score => _scoreF.floor();
  int combo = 1;
  int bestCombo = 1;
  static const int comboCap = 20;

  /// Time left before the combo starts falling apart. Combo is a statement
  /// about the last few seconds, not a counter that only resets on a crash.
  double comboTimer = 0;
  static const double comboWindow = 3.2;
  double get comboFrac => (comboTimer / comboWindow).clamp(0.0, 1.0);

  /// Combo pays out as a gentle multiplier rather than a raw factor, which is
  /// what used to make late-run scores explode.
  double get comboMul => 1 + (combo - 1) * 0.08;

  double multiplierTime = 0;
  double gateMult = 1;
  double get scoreMult =>
      gateMult * (overdriveActive ? 2.0 : 1.0) * (1 + chain * 0.01);

  /// Registers a scoring action: extends the combo and refreshes its window.
  void _bump([int by = 1]) {
    combo = (combo + by).clamp(1, comboCap);
    comboTimer = comboWindow;
  }

  // Cargo / stats
  int spheres = 0;
  int crystals = 0;
  int grazes = 0;
  int tricks = 0;

  // State
  late int maxIntegrity;
  late int integrity;
  bool started = false;
  bool paused = false;
  bool finished = false;
  bool won = false;
  bool crashedEver = false;
  double shake = 0;
  double countdown = 3.0;
  double _flash = 0;
  double get flash => _flash;

  final List<Entity> entities = [];
  final List<Particle> particles = [];
  final List<Floater> floaters = [];

  static const double _spawnBaseY = -100.0;
  double _spawnAcc = 0;
  double _nextGap = 320;

  /// Vertical extent of the pattern spawned last, used to keep waves apart.
  double _patternLen = 0;
  double _policeSfxCd = 0;
  int _patternRot = 0;

  RunResult? result;

  void configure(Size s) {
    if (s == size && laneW != 0) return;
    size = s;
    laneW = s.width / lanes;
    playerY = s.height * 0.80;
    laneAnim = playerLane.toDouble();
    hunterGap = min(hunterGap, s.height * 0.55);
    if (freeControl && !_freePlaced) {
      freeX = s.width / 2;
      freeY = s.height * (mode == GameMode.boss ? 0.80 : 0.70);
      _freePlaced = true;
    }
    // Park the gunship before the countdown so it is on screen from frame one.
    if (mode == GameMode.boss && bossY == 0) {
      bossX = s.width / 2;
      bossY = s.height * 0.15;
    }
  }

  // ---- Input -------------------------------------------------------------
  /// Free-flight steering. The finger adds momentum rather than teleporting the
  /// board, so the craft has to be flown.
  void steer(double dx, double dy) {
    if (finished || !started || !freeControl) return;
    freeVX += dx * 14;
    freeVY += dy * 14;
  }

  /// Context tap: fire the cannon in the duel, barrel roll in free flight.
  void primaryAction() {
    switch (mode) {
      case GameMode.boss:
        fire();
        break;
      case GameMode.flight:
        barrelRoll();
        break;
      default:
        jump();
    }
  }

  void fire() {
    if (finished || !started || mode != GameMode.boss) return;
    if (charge < 1) {
      onSound('hit');
      return;
    }
    charge = 0;
    entities.add(Entity(
      kind: EntityKind.bolt,
      y: playerDrawY - laneW * 0.45,
      lane: 0,
      sprite: 0,
      size: laneW * 0.3,
      ax: playerX,
      vyOwn: -1250,
      scrolls: false,
    ));
    onSound('turbo');
  }

  void barrelRoll() {
    if (finished || !started || !freeControl) return;
    if (rollCd > 0 || spinning) return;
    rollCd = rollCdMax;
    spinning = true;
    spinAngle = 0;
    invuln = max(invuln, 0.6);
    tricks++;
    _bump();
    _scoreF += 260 * comboMul * scoreMult;
    _addOverdrive(0.10);
    onSound('drift');
    _floater('BARREL ROLL', 2, scale: 1.1);
  }

  void moveLeft() {
    if (finished || !started) return;
    if (freeControl) {
      freeVX -= 420;
      return;
    }
    if (playerLane > 0) {
      playerLane--;
      tilt = -0.35;
      onSound('drift');
    }
  }

  void moveRight() {
    if (finished || !started) return;
    if (freeControl) {
      freeVX += 420;
      return;
    }
    if (playerLane < lanes - 1) {
      playerLane++;
      tilt = 0.35;
      onSound('drift');
    }
  }

  void jump() {
    if (finished || !started) return;
    // There is no ground to leave in the free-flight modes.
    if (freeControl) return;
    if (airborne) {
      if (!spinning) {
        spinning = true;
        onSound('drift');
      }
      return;
    }
    airborne = true;
    vy = 1180;
    onSound('jump');
  }

  void setDrift(bool on) {
    if (finished || !started || freeControl) return;
    if (on && !drifting) {
      drifting = true;
      driftTime = 0;
      onSound('drift');
    } else if (!on && drifting) {
      drifting = false;
      if (driftTime > 0.6) {
        drifts++;
        _bump();
        _scoreF += 220 * comboMul * scoreMult;
        _addOverdrive(0.04);
      }
      driftTime = 0;
    }
  }

  void activateTurbo() {
    if (finished || !started || turboActive) return;
    if (turbo < 0.3) return;
    turboActive = true;
    turboTime = 2.6;
    invuln = max(invuln, 2.6);
    turbos++;
    _pushHunter(110);
    onSound('turbo');
    _emit(28, boardSprite, turbo: true);
  }

  void togglePause() {
    if (finished) return;
    paused = !paused;
    notifyListeners();
  }

  // ---- Simulation --------------------------------------------------------
  void update(double dt) {
    if (finished || size == Size.zero) return;
    dt = dt.clamp(0.0, 0.05);

    if (!started) {
      countdown -= dt;
      _animatePlayerVisualOnly(dt);
      if (countdown <= 0) started = true;
      notifyListeners();
      return;
    }
    if (paused) {
      notifyListeners();
      return;
    }

    _elapsed += dt;

    // Endless keeps ramping long after other modes have finished.
    final rampCap = mode == GameMode.endless ? 190.0 : 105.0;
    final rampRate = mode == GameMode.endless ? 0.11 : 0.085;
    final ramp = min(rampCap, meters * rampRate);
    var speed = (baseSpeed + ramp) * contract.speedMul;
    if (turboActive) speed *= 1.38;
    if (overdriveActive) speed *= 1.18;
    if (boostTimer > 0) speed *= 1.28;
    // Flight throttles on altitude: fly high and you go fast, hug the bottom
    // and you buy yourself reaction time.
    if (mode == GameMode.flight) speed *= _altitudeThrottle();
    // The duel is a standing fight — the backdrop only drifts for atmosphere.
    if (mode == GameMode.boss) speed = 170;
    _speed = speed;
    final dx = speed * dt;
    distancePx += dx;

    if (freeControl) {
      _updateFreeMotion(dt);
    } else {
      laneAnim += (playerLane - laneAnim) * min(1, dt * 12 * upgrades.handling);
      tilt += (0 - tilt) * min(1, dt * 8);
    }

    if (airborne) {
      jumpOffset += vy * dt;
      vy -= 2600 * dt;
      if (spinning) spinAngle += dt * 13;
      if (jumpOffset <= 0) {
        jumpOffset = 0;
        airborne = false;
        vy = 0;
        onSound('land');
        if (spinning) {
          if (spinAngle > pi * 0.9) {
            tricks++;
            _bump();
            final gain = (320 * comboMul * scoreMult).round();
            _scoreF += gain;
            _addOverdrive(0.16);
            _pushHunter(90);
            _floater('TRICK +$gain', 1, scale: 1.15);
          }
          spinning = false;
          spinAngle = 0;
        }
      }
    }

    // Barrel roll spin has no landing to resolve against — it just plays out.
    if (freeControl && spinning) {
      spinAngle += dt * 15;
      if (spinAngle >= pi * 2) {
        spinning = false;
        spinAngle = 0;
      }
    }
    if (rollCd > 0) rollCd = max(0, rollCd - dt);

    // Combo decays one step at a time once you stop scoring, so it reflects
    // how you are playing right now instead of ratcheting up all run.
    if (combo > 1) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        combo--;
        comboTimer = combo > 1 ? 0.7 : 0;
      }
    }

    if (boostTimer > 0) boostTimer -= dt;
    if (invuln > 0) invuln -= dt;
    if (shieldFlash > 0) shieldFlash = max(0, shieldFlash - dt * 2.5);
    if (shake > 0) shake = max(0, shake - dt * 3);
    if (_flash > 0) _flash = max(0, _flash - dt * 2.2);
    if (_policeSfxCd > 0) _policeSfxCd -= dt;
    if (magnetTime > 0) magnetTime -= dt;
    if (multiplierTime > 0) {
      multiplierTime -= dt;
      if (multiplierTime <= 0) gateMult = 1;
    }
    if (overdriveActive) {
      overdriveTime -= dt;
      overdrive = (overdriveTime / 3.5).clamp(0.0, 1.0);
      if (showFx && _rng.nextDouble() < 0.5) _emit(2, turboSprite, turbo: true);
      if (overdriveTime <= 0) {
        overdrive = 0;
        onSound('turbo_off');
      }
    }

    if (drifting && !airborne) {
      driftTime += dt;
      turbo = (turbo + dt * 0.09).clamp(0.0, 1.0);
      _scoreF += dt * 40 * comboMul;
      if (showFx && _rng.nextDouble() < 0.6) _emit(1, trailSprite, drift: true);
    }
    if (turboActive) {
      turboTime -= dt;
      turbo = (turbo - dt * 0.42).clamp(0.0, 1.0);
      if (showFx) _emit(2, turboSprite, turbo: true);
      if (turboTime <= 0 || turbo <= 0) {
        turboActive = false;
        onSound('turbo_off');
      }
    }

    // Distance is not an achievement when you are standing and fighting.
    if (mode != GameMode.boss) _scoreF += dx * 0.05 * scoreMult;
    bestCombo = max(bestCombo, combo);

    _spawnAcc += dx;
    if (_spawnAcc >= _nextGap) {
      _spawnAcc = 0;
      // Measure how far the pattern actually reaches so the next one is queued
      // behind it instead of on top of it — that overlap is what turned the
      // road into a wall of objects.
      final before = entities.length;
      _spawn();
      var topY = _spawnBaseY;
      for (var i = before; i < entities.length; i++) {
        topY = min(topY, entities[i].y);
      }
      _patternLen = _spawnBaseY - topY;
      _nextGap = _gapForMode();
    }

    _updateEntities(dt, dx);
    if (freeControl) {
      _resolveFree();
    } else {
      _resolve();
    }
    _cullEntities();

    _updateParticles(dt);
    _updateFloaters(dt);
    _updateMode(dt);

    if (!finished && routeTargetMeters.isFinite && meters >= routeTargetMeters) {
      _finish(delivered: true);
    }

    notifyListeners();
  }

  /// Mode-specific clocks, hunters and fail states.
  void _updateMode(double dt) {
    switch (mode) {
      case GameMode.timeAttack:
        timeLeft -= dt;
        if (timeLeft <= 0) {
          timeLeft = 0;
          _finish(delivered: true);
        }
        break;
      case GameMode.pursuit:
        hunterPhase += dt;
        // The hunter closes faster the longer the run goes on.
        final closeRate = 22 + min(30.0, meters * 0.02);
        hunterGap -= closeRate * dt;
        if (hunterGap <= 0) {
          hunterGap = 0;
          caught = true;
          shake = 1;
          _finish(delivered: false);
        }
        break;
      case GameMode.boss:
        _updateBoss(dt);
        break;
      case GameMode.flight:
      case GameMode.endless:
      case GameMode.precision:
      case GameMode.campaign:
        break;
    }
  }

  /// 0 for the first stretch of a run, 1 once the player is warmed up. Every
  /// density decision reads from this so the opening is always learnable.
  double get _warmth => (meters / 700).clamp(0.0, 1.0);

  /// Seconds of clear road between waves, converted to pixels at the current
  /// speed. Expressed in time so acceleration never silently shortens the
  /// player's reaction window.
  double _gapForMode() {
    double secs;
    switch (mode) {
      case GameMode.flight:
        secs = 2.2 - 0.35 * _warmth;
        break;
      case GameMode.boss:
        secs = 1.5;
        break;
      case GameMode.precision:
        secs = 1.7 - 0.3 * _warmth;
        break;
      case GameMode.endless:
        // The only mode that genuinely tightens up over a long run.
        secs = (1.9 - 0.4 * _warmth) * max(0.78, 1 - meters / 8000 * 0.22);
        break;
      case GameMode.timeAttack:
      case GameMode.pursuit:
      case GameMode.campaign:
        secs = 1.9 - 0.45 * _warmth;
        break;
    }
    secs += _rng.nextDouble() * 0.45;
    // Long patterns push the next wave further out; the road always gets at
    // least ~0.8s of genuinely empty space between set pieces.
    return max(_speed * secs, _patternLen + _speed * 0.8);
  }

  // ---- Free flight ---------------------------------------------------------
  /// 1.0 at mid height, up to ~1.24 at the ceiling, down to ~0.82 at the floor.
  double _altitudeThrottle() {
    if (size.height == 0) return 1;
    final span = _freeBottomY - _freeTopY;
    if (span <= 0) return 1;
    final alt = 1 - ((freeY - _freeTopY) / span).clamp(0.0, 1.0);
    return 0.82 + 0.42 * alt;
  }

  void _updateFreeMotion(double dt) {
    final drag = min(1.0, dt * 9);
    freeVX -= freeVX * drag;
    freeVY -= freeVY * drag;
    freeX += freeVX * dt;
    freeY += freeVY * dt;

    final marginX = laneW * 0.42;
    if (freeX < marginX) {
      freeX = marginX;
      freeVX = -freeVX * 0.2;
    } else if (freeX > size.width - marginX) {
      freeX = size.width - marginX;
      freeVX = -freeVX * 0.2;
    }
    if (freeY < _freeTopY) {
      freeY = _freeTopY;
      freeVY = -freeVY * 0.2;
    } else if (freeY > _freeBottomY) {
      freeY = _freeBottomY;
      freeVY = -freeVY * 0.2;
    }
    if (!spinning) {
      tilt += ((freeVX / 1300).clamp(-0.5, 0.5) - tilt) * min(1, dt * 10);
    }
  }

  // ---- Boss duel -----------------------------------------------------------
  void _updateBoss(double dt) {
    bossY = size.height * 0.15;
    bossX = size.width / 2 + sin(_elapsed * 0.8) * size.width * 0.26;
    bossPhase = bossHp > 0.66 ? 1 : (bossHp > 0.33 ? 2 : 3);
    if (bossHitFlash > 0) bossHitFlash = max(0, bossHitFlash - dt * 2.6);

    if (sweepActive) {
      final travel = size.width / (bossPhase == 3 ? 1.15 : 1.7);
      sweepX += sweepDir * travel * dt;
      final band = laneW * 0.42;
      final immune = invuln > 0 || turboActive || overdriveActive;
      if (!immune && (sweepX - playerX).abs() < band) _hit(null);
      if (sweepX < -80 || sweepX > size.width + 80) sweepActive = false;
    }

    bossStateTimer -= dt;
    if (bossStateTimer > 0) return;

    switch (bossState) {
      case 'idle':
        bossAttack = 1 + _rng.nextInt(3);
        // Never stack two beams — one sweep on screen at a time is readable.
        if (bossAttack == 2 && sweepActive) bossAttack = 1;
        _telegraphAttack();
        bossState = 'telegraph';
        bossStateTimer = bossPhase == 3 ? 0.62 : 0.88;
        onSound('police');
        break;
      case 'telegraph':
        _launchBossAttack();
        bossState = 'attack';
        bossStateTimer = 0.45;
        break;
      default:
        telegraphX = const [];
        bossState = 'idle';
        bossStateTimer = bossPhase == 1 ? 1.5 : (bossPhase == 2 ? 1.1 : 0.8);
        break;
    }
  }

  void _telegraphAttack() {
    switch (bossAttack) {
      case 1: // Column volley.
        const cols = 5;
        final step = size.width / cols;
        final picks = <double>[];
        final count = bossPhase >= 2 ? 3 : 2;
        final taken = <int>{};
        while (taken.length < count) {
          taken.add(_rng.nextInt(cols));
        }
        for (final c in taken) {
          picks.add((c + 0.5) * step);
        }
        telegraphX = picks;
        break;
      case 2: // Sweeping beam — warn from the edge it starts on.
        sweepDir = _rng.nextBool() ? 1 : -1;
        sweepX = sweepDir > 0 ? -40 : size.width + 40;
        telegraphX = [sweepDir > 0 ? 6.0 : size.width - 6.0];
        break;
      default: // Mine fan straight from the hull.
        telegraphX = [bossX];
        break;
    }
  }

  void _launchBossAttack() {
    final startY = bossY + laneW * 0.6;
    switch (bossAttack) {
      case 1:
        final speed = 330.0 + bossPhase * 70;
        for (final x in telegraphX) {
          for (var i = 0; i < 3; i++) {
            entities.add(Entity(
              kind: EntityKind.bomb,
              y: startY - i * 78,
              lane: 0,
              sprite: 0,
              size: laneW * 0.42,
              ax: x,
              vyOwn: speed,
              scrolls: false,
            ));
          }
        }
        break;
      case 2:
        sweepActive = true;
        break;
      default:
        final n = 4 + bossPhase;
        for (var i = 0; i < n; i++) {
          final t = n == 1 ? 0.0 : (i / (n - 1)) * 2 - 1;
          entities.add(Entity(
            kind: EntityKind.bomb,
            y: startY,
            lane: 0,
            sprite: 0,
            size: laneW * 0.4,
            ax: bossX,
            vxOwn: t * 210,
            vyOwn: 230 + bossPhase * 30,
            scrolls: false,
          ));
        }
        break;
    }
    onSound('hit');
  }

  void _damageBoss() {
    bossHits++;
    bossHp = (bossHp - 0.12).clamp(0.0, 1.0);
    bossHitFlash = 1;
    shake = max(shake, 0.4);
    _flash = max(_flash, 0.35);
    _bump(2);
    _scoreF += 700 * comboMul * scoreMult;
    onSound('crystal');
    _floater('DIRECT HIT', 3, scale: 1.2);
    if (bossHp <= 0) _finish(delivered: true);
  }

  void _addCharge(double amount) {
    if (mode != GameMode.boss) return;
    final was = charge;
    charge = (charge + amount).clamp(0.0, 1.0);
    if (was < 1 && charge >= 1) {
      onSound('gate');
      _floater('CANNON READY', 1);
    }
  }

  void _animatePlayerVisualOnly(double dt) {
    laneAnim += (playerLane - laneAnim) * min(1, dt * 12);
    tilt += (0 - tilt) * min(1, dt * 8);
    _updateParticles(dt);
    _updateFloaters(dt);
  }

  void _updateEntities(double dt, double dx) {
    final px = playerX;
    for (final e in entities) {
      if (e.scrolls) e.y += dx;
      if (e.vyOwn != 0) e.y += e.vyOwn * dt;
      if (e.vxOwn != 0 && e.ax != null) {
        e.ax = e.ax! + e.vxOwn * dt;
        // Mines ricochet off the corridor walls instead of leaving play.
        final m = laneW * 0.3;
        if (e.ax! < m) {
          e.ax = m;
          e.vxOwn = -e.vxOwn;
        } else if (e.ax! > size.width - m) {
          e.ax = size.width - m;
          e.vxOwn = -e.vxOwn;
        }
      }
      e.phase += dt;

      // Cannon rounds detonate on the gunship.
      if (e.kind == EntityKind.bolt && !e.used) {
        if (e.y < bossY + laneW * 0.55 &&
            (entX(e) - bossX).abs() < laneW * 1.05 &&
            bossHp > 0) {
          e.used = true;
          _damageBoss();
        }
        continue;
      }

      if (e.chase && e.kind == EntityKind.police && !e.used) {
        e.aiTimer -= dt;
        if (e.aiTimer <= 0 && e.y > -40 && e.y < playerBaseY - 120) {
          e.aiTimer = 0.85;
          if (e.lane < playerLane) {
            e.lane++;
            e.drift -= laneW;
          } else if (e.lane > playerLane) {
            e.lane--;
            e.drift += laneW;
          }
        }
      }

      if (magnetActive &&
          (e.kind == EntityKind.sphere || e.kind == EntityKind.crystal) &&
          !e.used &&
          e.y > 40 &&
          e.y < playerBaseY + 40) {
        if (e.ax != null) {
          e.ax = e.ax! + (px - e.ax!) * min(1, dt * 6);
        } else {
          final targetX = px - laneCenterX(e.lane);
          e.drift += (targetX - e.drift) * min(1, dt * 6);
        }
      } else if (e.kind == EntityKind.police) {
        e.drift += (0 - e.drift) * min(1, dt * 5);
      }
    }
  }

  /// Removes off-screen entities and, in Precision, breaks the chain on any
  /// sphere that slipped past uncollected.
  void _cullEntities() {
    final limit = size.height + 240;
    if (mode == GameMode.precision) {
      for (final e in entities) {
        if (e.kind == EntityKind.sphere &&
            !e.used &&
            e.y > playerBaseY + laneW &&
            e.y < limit &&
            chain > 0) {
          chain = 0;
          combo = 1;
          comboTimer = 0;
          _floater('CHAIN LOST', 4);
          onSound('hit');
          break;
        }
      }
    }
    entities.removeWhere((e) =>
        e.y > limit ||
        e.y < -900 ||
        (e.used &&
            (e.kind == EntityKind.bolt || e.kind == EntityKind.bomb)));
  }

  /// Collision pass for the free-movement modes: circular hitboxes, real
  /// rectangles for walls, and no lane assumptions anywhere.
  void _resolveFree() {
    final pr = laneW * 0.34;
    final px = playerX;
    final py = playerBaseY;
    final immune = invuln > 0 || turboActive || overdriveActive;

    for (final e in entities) {
      if (e.used || e.kind == EntityKind.bolt) continue;
      final ex = entX(e);
      final dxp = (ex - px).abs();
      final dyp = (e.y - py).abs();

      switch (e.kind) {
        case EntityKind.sphere:
          final reach = pr + e.size * (magnetActive ? 0.9 : 0.55);
          if (dxp < reach && dyp < reach) {
            e.used = true;
            spheres++;
            _bump();
            _scoreF += 55 * comboMul * scoreMult * upgrades.cargoScore;
            turbo = (turbo + 0.05).clamp(0.0, 1.0);
            _addOverdrive(0.022);
            _addCharge(0.34);
            onSound('sphere');
            if (showFx) _emit(4, sphereSprite);
          }
          break;
        case EntityKind.crystal:
          final reach = pr + e.size * (magnetActive ? 0.9 : 0.55);
          if (dxp < reach && dyp < reach) {
            e.used = true;
            crystals++;
            _bump();
            _scoreF += 220 * comboMul * scoreMult * upgrades.cargoScore;
            _addOverdrive(0.04);
            _addCharge(1.0);
            onSound('crystal');
            if (showFx) _emit(8, e.sprite);
          }
          break;
        case EntityKind.ring:
          if (dyp < 26 && !e.used) {
            final r = e.size * 0.5;
            if (dxp < r * 0.22) {
              e.used = true;
              rings++;
              perfectRings++;
              _bump(2);
              final gain = (380 * comboMul * scoreMult).round();
              _scoreF += gain;
              turbo = (turbo + 0.12).clamp(0.0, 1.0);
              _addOverdrive(0.12);
              onSound('gate');
              _flash = max(_flash, 0.35);
              _floater('PERFECT +$gain', 1, scale: 1.2);
            } else if (dxp < r * 0.86) {
              e.used = true;
              rings++;
              _bump();
              final gain = (170 * comboMul * scoreMult).round();
              _scoreF += gain;
              turbo = (turbo + 0.06).clamp(0.0, 1.0);
              _addOverdrive(0.06);
              onSound('sphere');
              _floater('RING +$gain', 0);
            }
          }
          break;
        case EntityKind.wall:
          if (dxp < e.w * 0.5 + pr * 0.8 && dyp < e.size * 0.5 + pr * 0.8) {
            if (!immune) {
              e.used = true;
              _hit(e);
            }
          } else if (!e.grazed &&
              dyp < e.size * 0.6 &&
              dxp < e.w * 0.5 + pr * 1.8) {
            e.grazed = true;
            grazes++;
            _bump();
            final gain = (70 * comboMul * scoreMult).round();
            _scoreF += gain;
            _addOverdrive(0.07);
            onSound('sphere');
            _floater('GRAZE +$gain', 3);
          }
          break;
        case EntityKind.bomb:
          final reach = pr + e.size * 0.45;
          if (dxp < reach && dyp < reach) {
            if (!immune) {
              e.used = true;
              _hit(e);
            }
          }
          break;
        case EntityKind.shieldPU:
          if (dxp < pr + e.size * 0.6 && dyp < pr + e.size * 0.6) {
            e.used = true;
            shield = true;
            shieldFlash = 0.6;
            onSound('boost');
            _floater('SHIELD', 0);
          }
          break;
        case EntityKind.magnetPU:
          if (dxp < pr + e.size * 0.6 && dyp < pr + e.size * 0.6) {
            e.used = true;
            magnetTime = _magnetDuration;
            onSound('boost');
            _floater('MAGNET', 2);
          }
          break;
        case EntityKind.boost:
          if (dxp < pr + e.size * 0.5 && dyp < pr + e.size * 0.5) {
            e.used = true;
            boostTimer = 1.3;
            _scoreF += 40;
            onSound('boost');
            if (showFx) _emit(10, e.sprite, turbo: true);
          }
          break;
        default:
          break;
      }
    }
  }

  void _resolve() {
    final half = laneW * 0.5;
    for (final e in entities) {
      if (e.used) continue;
      final ex = entX(e);
      final dxp = (ex - playerX).abs();
      final dyp = (e.y - playerY);

      switch (e.kind) {
        case EntityKind.sphere:
          final reach = magnetActive ? half * 1.4 : half;
          if (dxp < reach && dyp.abs() < half) {
            e.used = true;
            spheres++;
            _bump();
            if (mode == GameMode.precision) {
              chain++;
              bestChain = max(bestChain, chain);
            }
            _scoreF += 55 * comboMul * scoreMult * upgrades.cargoScore;
            turbo = (turbo + 0.05).clamp(0.0, 1.0);
            _addOverdrive(0.022);
            _pushHunter(6);
            if (mode == GameMode.timeAttack) timeLeft += 0.4;
            onSound('sphere');
            if (showFx) _emit(5, sphereSprite);
          }
          break;
        case EntityKind.crystal:
          final reach = magnetActive ? half * 1.4 : half;
          if (dxp < reach && dyp.abs() < half) {
            e.used = true;
            crystals++;
            _bump();
            _scoreF += 220 * comboMul * scoreMult * upgrades.cargoScore;
            _addOverdrive(0.04);
            _pushHunter(18);
            if (mode == GameMode.timeAttack) timeLeft += 2.0;
            onSound('crystal');
            if (showFx) _emit(8, e.sprite);
          }
          break;
        case EntityKind.boost:
          if (dxp < half && dyp.abs() < half) {
            e.used = true;
            boostTimer = 1.3;
            _scoreF += 40;
            _pushHunter(40);
            onSound('boost');
            if (showFx) _emit(10, e.sprite, turbo: true);
          }
          break;
        case EntityKind.shieldPU:
          if (dxp < half * 1.2 && dyp.abs() < half) {
            e.used = true;
            shield = true;
            shieldFlash = 0.6;
            onSound('boost');
            _floater('SHIELD', 0);
          }
          break;
        case EntityKind.magnetPU:
          if (dxp < half * 1.2 && dyp.abs() < half) {
            e.used = true;
            magnetTime = _magnetDuration;
            onSound('boost');
            _floater('MAGNET', 2);
          }
          break;
        case EntityKind.ramp:
          if (dxp < half && !airborne && dyp.abs() < half) {
            e.used = true;
            jump();
            vy = 1360;
          }
          break;
        case EntityKind.gate:
          if (dyp.abs() < half * 0.6 && !e.used) {
            e.used = true;
            gateMult = 2;
            multiplierTime = 6;
            _scoreF += 280;
            onSound('gate');
            _flash = 0.5;
            _floater('x2 SCORE', 1);
          }
          break;
        case EntityKind.police:
        case EntityKind.barrier:
          final jumpable = e.kind == EntityKind.barrier;
          final cleared = jumpable && jumpOffset > laneW * 0.35;
          final immune = invuln > 0 || turboActive || overdriveActive;
          if (dxp < half * 0.82 && dyp.abs() < half * 0.8 && !cleared) {
            if (!immune) {
              e.used = true;
              _hit(e);
            }
          } else if (!e.grazed &&
              !cleared &&
              dyp.abs() < half * 0.5 &&
              dxp >= half * 0.82 &&
              dxp < half * 1.5) {
            e.grazed = true;
            grazes++;
            _bump();
            final gain = (70 * comboMul * scoreMult).round();
            _scoreF += gain;
            _addOverdrive(0.07);
            _pushHunter(50);
            onSound('sphere');
            _floater('GRAZE +$gain', 3);
          }
          break;
        case EntityKind.wall:
        case EntityKind.ring:
        case EntityKind.bomb:
        case EntityKind.bolt:
          break;
      }
    }
  }

  /// [e] is null for hazards that are not entities, such as the boss beam.
  void _hit(Entity? e) {
    if (shield) {
      shield = false;
      shieldFlash = 0.8;
      invuln = 1.3;
      shake = 0.6;
      onSound('hit');
      _floater('SHIELD BREAK', 0);
      if (showFx) _emit(14, e?.sprite ?? 0, crash: true);
      return;
    }

    crashedEver = true;
    combo = 1;
    comboTimer = 0;
    chain = 0;
    gateMult = 1;
    multiplierTime = 0;
    overdrive = max(0, overdrive - 0.4);
    shake = 1;
    invuln = 1.5;
    if (showFx) _emit(20, e?.sprite ?? 0, crash: true);
    _pushHunter(-170);
    // A hit knocks the cannon capacitor loose.
    if (mode == GameMode.boss) charge = max(0, charge - 0.5);

    // Time Attack trades hull damage for a brutal time penalty instead.
    if (mode == GameMode.timeAttack) {
      timeLeft = max(0, timeLeft - 5);
      _floater('-5s', 4, scale: 1.2);
      onSound('hit');
      return;
    }

    integrity--;
    if (_policeSfxCd <= 0) {
      onSound(integrity <= 0 ? 'crash' : 'hit');
      _policeSfxCd = 0.4;
    }
    if (integrity <= 0) {
      _finish(delivered: false);
    }
  }

  void _addOverdrive(double amount) {
    if (overdriveActive) return;
    overdrive = (overdrive + amount * upgrades.overdriveRate).clamp(0.0, 1.0);
    if (overdrive >= 1.0) {
      overdriveTime = 3.5;
      invuln = max(invuln, 3.5);
      magnetTime = max(magnetTime, 3.5);
      _pushHunter(140);
      onSound('turbo');
      _flash = 0.6;
      _floater('OVERDRIVE!', 4, scale: 1.4);
    }
  }

  /// Pursuit only: skilful play buys distance, mistakes give it back.
  void _pushHunter(double amount) {
    if (mode != GameMode.pursuit) return;
    hunterGap = (hunterGap + amount).clamp(0.0, hunterMaxGap);
  }

  // ---- Spawning ----------------------------------------------------------
  void _spawn() {
    const baseY = _spawnBaseY;

    // The free-movement modes have their own level vocabulary entirely.
    if (mode == GameMode.boss) {
      _spawnBossField(baseY);
      return;
    }
    if (mode == GameMode.flight) {
      _spawnFlight(baseY);
      return;
    }

    final r = _rng.nextDouble();

    if (r < 0.03) {
      entities.add(Entity(
          kind: EntityKind.shieldPU,
          y: baseY,
          lane: _rng.nextInt(lanes),
          sprite: 0,
          size: laneW * 0.6));
      return;
    }
    if (r < 0.06) {
      entities.add(Entity(
          kind: EntityKind.magnetPU,
          y: baseY,
          lane: _rng.nextInt(lanes),
          sprite: 0,
          size: laneW * 0.6));
      return;
    }

    // Precision runs a police-free flow course.
    if (mode == GameMode.precision) {
      _spawnPrecision(baseY);
      return;
    }

    _patternRot = (_patternRot + 1) % 7;
    switch (_patternRot) {
      case 0:
        _spawnObstacles(baseY);
        break;
      case 1:
        _spawnSphereArc(baseY);
        break;
      case 2:
        _spawnSlalom(baseY);
        break;
      case 3:
        _spawnRampCombo(baseY);
        break;
      case 4:
        _spawnTunnel(baseY);
        break;
      case 5:
        _maybeGate(baseY);
        break;
      default:
        // Hunting patrols are the hardest thing in the lane modes — hold them
        // back until the player has had room to settle in.
        if (_warmth >= 1) {
          _spawnChaser(baseY);
        } else {
          _spawnSphereArc(baseY);
        }
        break;
    }
  }

  double _freeX(double margin) =>
      margin + _rng.nextDouble() * max(1.0, size.width - margin * 2);

  /// Boss arena: no obstacles of its own — just the ammunition the player needs
  /// to keep the cannon fed while dodging.
  void _spawnBossField(double baseY) {
    final crystal = _rng.nextDouble() < 0.16;
    if (crystal) {
      entities.add(Entity(
        kind: EntityKind.crystal,
        y: baseY,
        lane: 0,
        sprite: _rng.nextInt(12),
        size: laneW * 0.55,
        ax: _freeX(laneW * 0.6),
      ));
      return;
    }
    final n = 3 + _rng.nextInt(3);
    final startX = _freeX(laneW * 0.7);
    final spread = (_rng.nextDouble() - 0.5) * laneW * 1.6;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      entities.add(Entity(
        kind: EntityKind.sphere,
        y: baseY - i * 56,
        lane: 0,
        sprite: sphereSprite,
        size: laneW * 0.46,
        ax: (startX + spread * t).clamp(laneW * 0.4, size.width - laneW * 0.4),
      ));
    }
    if (_rng.nextDouble() < 0.12) {
      entities.add(Entity(
        kind: EntityKind.shieldPU,
        y: baseY - 160,
        lane: 0,
        sprite: 0,
        size: laneW * 0.58,
        ax: _freeX(laneW * 0.7),
      ));
    }
  }

  /// Free flight: solid gap walls, hoop chains, sine streams and loose mines.
  void _spawnFlight(double baseY) {
    _patternRot = (_patternRot + 1) % 5;
    final w = size.width;
    switch (_patternRot) {
      case 0:
      case 3:
        // Gap wall — tightens the further you fly.
        final gapW = laneW * (1.35 - min(0.45, meters / 3000));
        final gapC = (laneW * 0.55 + _rng.nextDouble() * (w - laneW * 1.1))
            .clamp(gapW * 0.6, w - gapW * 0.6);
        _wallRow(baseY, gapC, gapW);
        for (var i = 0; i < 3; i++) {
          entities.add(Entity(
            kind: EntityKind.sphere,
            y: baseY - 110 - i * 54,
            lane: 0,
            sprite: sphereSprite,
            size: laneW * 0.46,
            ax: gapC,
          ));
        }
        break;
      case 1:
        // Hoop chain that wanders across the corridor.
        var x = _freeX(laneW * 0.9);
        for (var i = 0; i < 4; i++) {
          entities.add(Entity(
            kind: EntityKind.ring,
            y: baseY - i * 145,
            lane: 0,
            sprite: 0,
            size: laneW * 1.05,
            ax: x,
          ));
          x = (x + (_rng.nextDouble() - 0.5) * laneW * 1.7)
              .clamp(laneW * 0.75, w - laneW * 0.75);
        }
        break;
      case 2:
        // Sine stream of cargo — reward for smooth flying.
        final cx = w / 2;
        final amp = w * 0.3;
        final ph = _rng.nextDouble() * pi;
        for (var i = 0; i < 10; i++) {
          entities.add(Entity(
            kind: EntityKind.sphere,
            y: baseY - i * 52,
            lane: 0,
            sprite: sphereSprite,
            size: laneW * 0.44,
            ax: cx + sin(ph + i * 0.55) * amp,
          ));
        }
        if (_rng.nextDouble() < 0.4) {
          entities.add(Entity(
            kind: EntityKind.magnetPU,
            y: baseY - 560,
            lane: 0,
            sprite: 0,
            size: laneW * 0.58,
            ax: _freeX(laneW * 0.7),
          ));
        }
        break;
      default:
        // Drifting mines that bounce off the corridor walls.
        for (var i = 0; i < 3; i++) {
          entities.add(Entity(
            kind: EntityKind.bomb,
            y: baseY - i * 130,
            lane: 0,
            sprite: 0,
            size: laneW * 0.46,
            ax: _freeX(laneW * 0.5),
            vxOwn: (_rng.nextDouble() - 0.5) * 190,
          ));
        }
        entities.add(Entity(
          kind: EntityKind.crystal,
          y: baseY - 330,
          lane: 0,
          sprite: _rng.nextInt(12),
          size: laneW * 0.55,
          ax: _freeX(laneW * 0.6),
        ));
        break;
    }
  }

  void _wallRow(double y, double gapCentre, double gapW) {
    final h = laneW * 0.44;
    final leftW = (gapCentre - gapW / 2).clamp(0.0, size.width);
    final rightStart = (gapCentre + gapW / 2).clamp(0.0, size.width);
    final rightW = size.width - rightStart;
    if (leftW > 10) {
      entities.add(Entity(
        kind: EntityKind.wall,
        y: y,
        lane: 0,
        sprite: 0,
        size: h,
        ax: leftW / 2,
        w: leftW,
      ));
    }
    if (rightW > 10) {
      entities.add(Entity(
        kind: EntityKind.wall,
        y: y,
        lane: 0,
        sprite: 0,
        size: h,
        ax: rightStart + rightW / 2,
        w: rightW,
      ));
    }
  }

  void _spawnPrecision(double baseY) {
    _patternRot = (_patternRot + 1) % 4;
    switch (_patternRot) {
      case 0:
        _spawnSphereArc(baseY);
        break;
      case 1:
        _maybeGate(baseY);
        break;
      case 2:
        _spawnRampCombo(baseY);
        break;
      default:
        // Barrier squeeze with a full sphere line through the gap.
        final open = _rng.nextInt(lanes);
        for (var lane = 0; lane < lanes; lane++) {
          if (lane == open) continue;
          entities.add(Entity(
              kind: EntityKind.barrier,
              y: baseY,
              lane: lane,
              sprite: _rng.nextInt(24),
              size: laneW * 0.8));
        }
        for (var i = 0; i < 4; i++) {
          entities.add(Entity(
              kind: EntityKind.sphere,
              y: baseY - i * 60,
              lane: open,
              sprite: sphereSprite,
              size: laneW * 0.5));
        }
        break;
    }
  }

  void _spawnObstacles(double baseY) {
    final freeLane = _rng.nextInt(lanes);
    // A second blocked lane only appears once the run is properly under way.
    var extra = (contract.id == 'overloaded' && _warmth >= 1) ? 1 : 0;
    if (mode == GameMode.endless && meters > 2600) extra += 1;
    var placed = 0;
    for (var lane = 0; lane < lanes; lane++) {
      if (lane == freeLane) continue;
      if (placed >= 1 + extra) break;
      if (_rng.nextDouble() < 0.7) {
        final police = _rng.nextDouble() < 0.5;
        entities.add(Entity(
          kind: police ? EntityKind.police : EntityKind.barrier,
          y: baseY - _rng.nextDouble() * 30,
          lane: lane,
          sprite: police ? _rng.nextInt(6) : _rng.nextInt(24),
          size: laneW * 0.8,
        ));
        placed++;
      }
    }
    for (var i = 0; i < 3; i++) {
      entities.add(Entity(
          kind: EntityKind.sphere,
          y: baseY - 120 - i * 62,
          lane: freeLane,
          sprite: sphereSprite,
          size: laneW * 0.5));
    }
  }

  void _spawnSphereArc(double baseY) {
    var lane = 0;
    var dir = 1;
    for (var i = 0; i < lanes * 2 + 1; i++) {
      entities.add(Entity(
          kind: EntityKind.sphere,
          y: baseY - i * 58,
          lane: lane,
          sprite: sphereSprite,
          size: laneW * 0.5));
      lane += dir;
      if (lane >= lanes) {
        lane = lanes - 1;
        dir = -1;
      } else if (lane < 0) {
        lane = 0;
        dir = 1;
      }
    }
  }

  void _spawnSlalom(double baseY) {
    var lane = _rng.nextInt(lanes);
    final steps = _warmth >= 1 ? 3 : 2;
    for (var i = 0; i < steps; i++) {
      entities.add(Entity(
          kind: EntityKind.barrier,
          y: baseY - i * 185,
          lane: lane,
          sprite: _rng.nextInt(24),
          size: laneW * 0.8));
      final open = lane == 0 ? lanes - 1 : 0;
      entities.add(Entity(
          kind: EntityKind.sphere,
          y: baseY - i * 185 - 92,
          lane: open,
          sprite: sphereSprite,
          size: laneW * 0.5));
      lane = (lane + 1) % lanes;
    }
  }

  void _spawnRampCombo(double baseY) {
    final lane = _rng.nextInt(lanes);
    entities.add(Entity(
        kind: EntityKind.ramp,
        y: baseY,
        lane: lane,
        sprite: _rng.nextInt(10),
        size: laneW * 0.85));
    for (var i = 0; i < 4; i++) {
      entities.add(Entity(
          kind: i == 3 ? EntityKind.crystal : EntityKind.sphere,
          y: baseY - 150 - i * 66,
          lane: lane,
          sprite: i == 3 ? _rng.nextInt(12) : sphereSprite,
          size: laneW * (i == 3 ? 0.55 : 0.5)));
    }
  }

  void _spawnTunnel(double baseY) {
    if (lanes >= 3) {
      entities.add(Entity(
          kind: EntityKind.barrier,
          y: baseY,
          lane: 0,
          sprite: _rng.nextInt(24),
          size: laneW * 0.8));
      entities.add(Entity(
          kind: EntityKind.barrier,
          y: baseY,
          lane: lanes - 1,
          sprite: _rng.nextInt(24),
          size: laneW * 0.8));
      entities.add(Entity(
          kind: EntityKind.boost,
          y: baseY - 60,
          lane: 1,
          sprite: _rng.nextInt(6),
          size: laneW * 0.7));
    } else {
      _spawnObstacles(baseY);
    }
  }

  void _maybeGate(double baseY) {
    entities.add(Entity(
        kind: EntityKind.gate,
        y: baseY,
        lane: 1,
        sprite: _rng.nextInt(5),
        size: size.width));
    for (var i = 0; i < 3; i++) {
      entities.add(Entity(
          kind: EntityKind.crystal,
          y: baseY - 120 - i * 70,
          lane: _rng.nextInt(lanes),
          sprite: _rng.nextInt(12),
          size: laneW * 0.55));
    }
  }

  void _spawnChaser(double baseY) {
    final lane = _rng.nextInt(lanes);
    entities.add(Entity(
      kind: EntityKind.police,
      y: baseY,
      lane: lane,
      sprite: _rng.nextInt(6),
      size: laneW * 0.8,
      chase: true,
      aiTimer: 0.9,
    ));
    if (_policeSfxCd <= 0) {
      onSound('police');
      _policeSfxCd = 2.5;
    }
    final safe = (lane + 1) % lanes;
    for (var i = 0; i < 2; i++) {
      entities.add(Entity(
          kind: EntityKind.sphere,
          y: baseY - 140 - i * 60,
          lane: safe,
          sprite: sphereSprite,
          size: laneW * 0.5));
    }
  }

  // ---- Particles / floaters ---------------------------------------------
  void _emit(int count, int sprite,
      {bool turbo = false, bool crash = false, bool drift = false}) {
    if (!showFx) return;
    if (particles.length > 110) return;
    final px = playerX;
    final py = playerDrawY + (drift || turbo ? laneW * 0.3 : 0);
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = crash
          ? 60 + _rng.nextDouble() * 220
          : turbo
              ? 120 + _rng.nextDouble() * 160
              : 30 + _rng.nextDouble() * 90;
      final backward = turbo || drift;
      final vx =
          backward ? (_rng.nextDouble() - 0.5) * sp * 0.5 : cos(a) * sp * 0.6;
      final vyp =
          backward ? sp : (crash ? sin(a) * sp * 0.6 : sin(a) * sp * 0.6 + 40);
      particles.add(Particle(
        px,
        py,
        vx,
        vyp,
        crash ? 0.6 : 0.4 + _rng.nextDouble() * 0.3,
        crash ? 3 + _rng.nextDouble() * 4 : 2 + _rng.nextDouble() * 3,
        crash ? 3 : (turbo ? 1 : (drift ? 2 : 0)),
      ));
    }
  }

  void _floater(String text, int color, {double scale = 1}) {
    floaters.add(Floater(
        playerX, playerDrawY - laneW * 0.9, text, color, 1.1, scale: scale));
    if (floaters.length > 8) floaters.removeAt(0);
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 60 * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void _updateFloaters(double dt) {
    for (final f in floaters) {
      f.y -= dt * 60;
      f.life -= dt;
    }
    floaters.removeWhere((f) => f.life <= 0);
  }

  // ---- Objectives --------------------------------------------------------
  int objectiveProgress(LevelObjective o) {
    switch (o.type) {
      case ObjectiveType.spheres:
        return spheres;
      case ObjectiveType.crystals:
        return crystals;
      case ObjectiveType.grazes:
        return grazes;
      case ObjectiveType.tricks:
        return tricks;
      case ObjectiveType.drifts:
        return drifts;
      case ObjectiveType.turbos:
        return turbos;
      case ObjectiveType.score:
        return score;
      case ObjectiveType.noCrash:
        return crashedEver ? 0 : 1;
      case ObjectiveType.combo:
        return bestCombo;
      case ObjectiveType.rings:
        return rings;
      case ObjectiveType.chain:
        return bestChain;
    }
  }

  bool objectiveMet(LevelObjective o) => objectiveProgress(o) >= o.target;

  // ---- Finish ------------------------------------------------------------
  void _finish({required bool delivered}) {
    if (finished) return;
    finished = true;
    won = delivered;

    final objectives = level?.objectives.map(objectiveMet).toList() ?? const [];

    String rating;
    if (delivered) {
      if (!crashedEver && score >= 9000) {
        rating = 'Platinum';
      } else if (score >= 5000) {
        rating = 'Gold';
      } else if (score >= 2200) {
        rating = 'Silver';
      } else {
        rating = 'Bronze';
      }
    } else {
      rating = 'Failed';
    }

    // Credits track the things the player actually did, with score as the
    // broad measure and the skill actions each worth a small flat bonus.
    final baseCredits = crystals * 20 +
        grazes * 6 +
        rings * 10 +
        (score * 0.035).round();
    final delivBonus = delivered ? 140 + district.index * 55 : 0;
    final districtMul = 1.0 + district.index * 0.12;
    final credits = ((baseCredits + delivBonus) *
            contract.rewardMul *
            districtMul *
            _modePayoutMul(delivered) *
            upgrades.payout)
        .round();

    onSound(delivered ? 'delivery' : 'fail');

    result = RunResult(
      score: score,
      distance: meters,
      spheres: spheres,
      crystals: crystals,
      credits: credits,
      bestCombo: bestCombo,
      turbos: turbos,
      drifts: drifts,
      grazes: grazes,
      tricks: tricks,
      delivered: delivered,
      crashed: crashedEver,
      rating: rating,
      contractId: contract.id,
      districtId: district.id,
      modeId: Modes.info(mode).id,
      levelId: level?.id,
      objectivesMet: objectives,
      modeValue: _modeValue(),
    );
    notifyListeners();
  }

  /// Endless and Time Attack always "end", so a hard failure penalty would be
  /// unfair — they pay out on merit instead.
  double _modePayoutMul(bool delivered) {
    switch (mode) {
      case GameMode.endless:
        return 0.85;
      case GameMode.timeAttack:
        return 0.9;
      case GameMode.pursuit:
        return delivered ? 1.2 : 0.5;
      case GameMode.flight:
        return delivered ? 1.15 : 0.4;
      case GameMode.boss:
        // Downing the gunship is the biggest single payday in the game.
        return delivered ? 1.9 : 0.45;
      case GameMode.precision:
      case GameMode.campaign:
        return delivered ? 1.0 : 0.35;
    }
  }

  double _modeValue() {
    switch (mode) {
      case GameMode.timeAttack:
        return timeLeft;
      case GameMode.pursuit:
        return hunterGap;
      case GameMode.precision:
        return bestChain.toDouble();
      case GameMode.flight:
        return rings.toDouble();
      case GameMode.boss:
        return (1 - bossHp) * 100;
      case GameMode.endless:
      case GameMode.campaign:
        return _elapsed;
    }
  }
}
