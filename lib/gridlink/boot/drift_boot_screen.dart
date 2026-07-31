import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/loading_screen.dart';
import '../core/link_models.dart';
import '../drift_router.dart';
import '../infra/trace_signal.dart';
import '../pages/dead_signal_page.dart';
import '../pages/neon_portal.dart';
import '../pages/pulse_invitation.dart';

const String _hBg =
    'assets/Neon_Drift_Board_additional_assets/Horizontal_Loading_Screen.webp';
const String _vBg =
    'assets/Neon_Drift_Board_additional_assets/Vertical_Loading_Screen.webp';

/// Boot splash + gray/white routing point. Renders the neon loading art while
/// [DriftRouter.decide] runs the attribution -> config pipeline, then routes:
/// organic -> the game (via LoadingScreen), non-organic -> the WebView portal.
class DriftBootScreen extends StatefulWidget {
  const DriftBootScreen({super.key, this.router});

  final DriftRouter? router;

  @override
  State<DriftBootScreen> createState() => _DriftBootScreenState();
}

class _DriftBootScreenState extends State<DriftBootScreen> {
  // Displayed value of the bar. Never assigned directly from the router —
  // it is only nudged by the creep ticker (and snapped to 1.0 on finish).
  double _progress = 0;
  // Real progress reported by the router. The bar creeps toward this value
  // continuously so long pauses (e.g. AppsFlyer conversion callback) don't
  // freeze the bar visually while the pipeline is still working.
  double _realProgress = 0;
  // Timestamp of the router.decide -> progress(1.0) transition, and the
  // displayed progress at that moment. Once these are set the ticker
  // switches into the linear final-ease mode.
  DateTime? _doneAt;
  double _doneStart = 0;
  LaneTarget? _target;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startedAt;
  Timer? _deadline;
  Timer? _creepTicker;
  static const Duration _minSplash = Duration(milliseconds: 1400);
  // 60fps redraw. The bar's visible width is only ~250px, so smaller ticks
  // would advance by sub-pixel amounts and *look* frozen to the user even
  // though _progress is technically increasing.
  static const Duration _creepInterval = Duration(milliseconds: 16);
  // Time constant (seconds) for the asymptotic autonomous fill. Bar hits
  // ~0.63 at 1x, ~0.86 at 2x, ~0.95 at 3x. Chosen so a typical cold-start
  // (~5–10s router pipeline) sees the bar climb naturally without ever
  // pinning at the ceiling and looking frozen.
  static const double _autoFillTauSeconds = 4.5;
  // Ceiling for the autonomous fill — router must supply a real milestone
  // (or actually complete) to push the bar beyond this.
  static const double _autoFillCeiling = 0.94;
  // Time (ms) to linearly ease the bar from wherever it is to full 1.0
  // once the router reports completion. Long enough to be visible, short
  // enough not to feel sluggish after the pipeline actually finished.
  static const int _finalEaseMs = 420;
  // Hard safety cap. This must be strictly larger than every internal
  // timeout in the pipeline combined (relay.boot ~3.5s + ATT dialog user
  // delay + AppsFlyer SDK init + attribution.awaitSignals + gate dispatch
  // timeout), otherwise a non-organic install can be misrouted to the
  // native game just because the user was slow to tap the ATT dialog.
  static const Duration _safetyDeadline = Duration(seconds: 75);

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _deadline = Timer(_safetyDeadline, () {
      if (mounted && !_navigating && _target == null) {
        ndbTrace(() => '[NDB.BOOT] safety deadline hit -> NativeLane');
        _target = const NativeLane();
        _enterTarget();
      }
    });
    _creepTicker = Timer.periodic(_creepInterval, (_) => _tickCreep());
  }

  void _tickCreep() {
    if (!mounted || _navigating) return;
    final now = DateTime.now();
    double next;
    if (_doneAt != null) {
      // Final ease: linearly interpolate from wherever we were when the
      // router finished to a full 1.0, over _finalEaseMs.
      final sinceDone = now.difference(_doneAt!).inMilliseconds / _finalEaseMs;
      final frac = sinceDone.clamp(0.0, 1.0);
      next = _doneStart + (1.0 - _doneStart) * frac;
    } else {
      // Autonomous asymptotic fill. Never crosses [_autoFillCeiling] until
      // the router actually finishes; router milestones can push the bar
      // forward faster than the asymptote if they arrive early.
      final elapsedSec = now.difference(_startedAt).inMilliseconds / 1000.0;
      final autoFill = 1.0 - math.exp(-elapsedSec / _autoFillTauSeconds);
      next = math
          .max(autoFill, _realProgress)
          .clamp(0.0, _autoFillCeiling);
    }
    next = next.clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.0015 ||
        (next == 1.0 && _progress != 1.0)) {
      setState(() => _progress = next);
    }
  }

  void _reportRealProgress(double value) {
    _realProgress = value.clamp(0.0, 1.0);
    if (_realProgress >= 1.0 && _doneAt == null) {
      _doneAt = DateTime.now();
      _doneStart = _progress;
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _creepTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final router = widget.router;
    if (router == null) {
      _target = const NativeLane();
      _reportRealProgress(1);
      _enterTarget();
      return;
    }
    try {
      _target = await router.decide(
        onProgress: (value) {
          if (mounted) _reportRealProgress(value);
        },
      );
    } catch (error) {
      ndbTrace(() => '[NDB.BOOT] router.decide threw: $error -> NativeLane');
      _target = const NativeLane();
    }
    _reportRealProgress(1);
    _enterTarget();
  }

  Future<void> _enterTarget() async {
    if (_navigating || _target == null) return;
    final elapsed = DateTime.now().difference(_startedAt);
    // We must hold long enough for BOTH (a) the minimum splash duration and
    // (b) the final-ease animation of the progress bar. Skipping (b) is
    // what caused the "empty bar then suddenly notif screen" jump on
    // returning users where the router resolves in a few hundred ms.
    final easeHold = Duration(milliseconds: _finalEaseMs + 80);
    Duration wait = Duration.zero;
    if (elapsed < _minSplash) wait = _minSplash - elapsed;
    if (easeHold > wait) wait = easeHold;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    _deadline?.cancel();
    _creepTicker?.cancel();
    await _openLane(_target!);
  }

  Future<void> _openLane(LaneTarget target) async {
    final router = widget.router;

    // Organic / gate disabled -> the game (its own LoadingScreen preloads
    // audio + sprites, then routes to /home).
    if (target is NativeLane || router == null) {
      ndbTrace(() => '[NDB.BOOT] enter NativeLane -> LoadingScreen');
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    if (target is DarkLane) {
      ndbTrace(() => '[NDB.BOOT] enter DarkLane -> DeadSignalPage');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DeadSignalPage(
            probe: router.probe,
            retryBuilder: (_) => DriftBootScreen(router: router),
          ),
        ),
      );
      return;
    }

    if (target is PortalLane) {
      Widget portalBuilder(BuildContext _) => NeonPortal(
        url: target.url,
        coldLaunch: target.coldLaunch,
        vault: router.vault,
        probe: router.probe,
        relay: router.relay,
        agent: router.agent,
      );

      final wantsInvite = router.vault.shouldShowPushInvite;
      final canOffer = wantsInvite && await router.relay.canOfferPermission();
      ndbTrace(
        () => '[NDB.BOOT] enter PortalLane cold=${target.coldLaunch} '
            'wantsInvite=$wantsInvite canOffer=$canOffer url=${target.url}',
      );

      if (canOffer) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PulseInvitation(
              vault: router.vault,
              relay: router.relay,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final size = MediaQuery.of(context).size;
    final barWidth = isLandscape ? size.width * 0.40 : size.width * 0.68;

    return Scaffold(
      backgroundColor: const Color(0xFF080716),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            isLandscape ? _hBg : _vBg,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF080716)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLandscape ? 22 : 64),
                child: _BootBar(progress: _progress, width: barWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootBar extends StatelessWidget {
  const _BootBar({required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    // We render [progress] directly instead of wrapping it in a
    // TweenAnimationBuilder because the outer creep ticker already updates
    // us at 60fps. A tween here would restart on every incoming value and
    // permanently lag behind the real progress, making the fill *look*
    // frozen even while _progress is climbing on the state side.
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        // Non-transparent inner track so an empty bar is still visibly
        // present against the busy neon-city background.
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF23F0FF), width: 2.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF23F0FF).withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clamped <= 0 ? 0.001 : clamped,
              // Container (NOT DecoratedBox) is critical: DecoratedBox with
              // no child collapses to 0×0 inside FractionallySizedBox, so
              // the gradient never gets painted. Container expands to the
              // tight width constraint imposed by FractionallySizedBox.
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color(0xFF23F0FF),
                      Color(0xFF8B4CFF),
                      Color(0xFFFF3DE0),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0xAAFF3DE0),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
