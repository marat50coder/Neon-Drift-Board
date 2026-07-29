import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio.dart';
import '../game/sprites.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_loader_bar.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const String _vBg =
      'assets/Neon_Drift_Board_additional_assets/Vertical_Loading_Screen.webp';
  static const String _hBg =
      'assets/Neon_Drift_Board_additional_assets/Horizontal_Loading_Screen.webp';

  double _progress = 0;
  int _dots = 0;
  Timer? _dotTimer;
  bool _realDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // The loading screen may appear in either orientation.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _dotTimer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
    _startRealInit();
    _runProgress();
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRealInit() async {
    try {
      await Audio.I.init();
      await Sprites.I.preload();
    } catch (_) {
      // Never block the loader on an asset error.
    }
    _realDone = true;
  }

  /// Staged, always-terminating progress. Fills in visible stages and only
  /// completes to 100% once real initialization has finished, guaranteeing the
  /// bar reaches exactly 100% right before launch (never stalls at 97%).
  Future<void> _runProgress() async {
    const stages = <List<num>>[
      [0.16, 480],
      [0.34, 520],
      [0.55, 560],
      [0.72, 520],
      [0.88, 620],
    ];
    for (final s in stages) {
      await _animateTo(s[0].toDouble(), s[1].toInt());
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
    }
    // Wait (briefly, capped) for real init so 100% is truthful.
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (!_realDone && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    await _animateTo(1.0, 460);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    _goHome();
  }

  Future<void> _animateTo(double target, int ms) async {
    final start = _progress;
    final steps = (ms / 16).round().clamp(1, 1000);
    for (var i = 1; i <= steps; i++) {
      if (!mounted) return;
      final f = Curves.easeInOut.transform(i / steps);
      setState(() => _progress = start + (target - start) * f);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (mounted) setState(() => _progress = target);
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    // The game is strictly vertical: lock the rest of the app to portrait.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final size = MediaQuery.of(context).size;
    final pct = (_progress * 100).round();
    final bg = isPortrait ? _vBg : _hBg;

    final barWidth = isPortrait ? size.width * 0.68 : size.width * 0.40;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          // Bottom scrim for text legibility.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.bgDeep.withValues(alpha: isPortrait ? 0.75 : 0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: isPortrait ? 64 : 22),
                child: _loaderBlock(barWidth, pct, isPortrait),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loaderBlock(double barWidth, int pct, bool isPortrait) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Loading" caption with animated dots — ON TOP.
        Text(
          'LOADING${'.' * _dots}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppText.display,
            fontWeight: FontWeight.w800,
            fontSize: isPortrait ? 20 : 16,
            letterSpacing: 3,
            color: Colors.white,
            shadows: const [
              Shadow(color: AppColors.cyan, blurRadius: 16),
              Shadow(color: AppColors.magenta, blurRadius: 22),
            ],
          ),
        ),
        SizedBox(height: isPortrait ? 16 : 10),
        // Left-to-right progress bar.
        NeonLoaderBar(
          progress: _progress,
          width: barWidth,
          height: isPortrait ? 16 : 12,
        ),
        SizedBox(height: isPortrait ? 12 : 8),
        // Percentage number — BELOW the bar.
        Text(
          '$pct%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppText.display,
            fontWeight: FontWeight.w900,
            fontSize: isPortrait ? 26 : 20,
            letterSpacing: 1,
            color: Colors.white,
            shadows: const [Shadow(color: AppColors.cyan, blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}
