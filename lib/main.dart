import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio.dart';
import 'data/game_state.dart';
import 'gridlink/boot/drift_boot_screen.dart';
import 'gridlink/config/drift_gate_config.dart';
import 'gridlink/drift_router.dart';
import 'gridlink/infra/drift_vault.dart';
import 'gridlink/infra/gate_dispatch.dart';
import 'gridlink/infra/pulse_agent.dart';
import 'gridlink/infra/pulse_relay.dart';
import 'gridlink/infra/signal_probe.dart';
import 'gridlink/infra/trace_signal.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── Gridlink (gray flow) warm-up ──────────────────────────────────────
  final vault = DriftVault();
  final agent = PulseAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  var productionServicesReady = false;
  if (DriftGateConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
    } catch (error) {
      assert(() {
        debugPrint('[NDB.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        assert(() {
          debugPrint('[NDB.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  }

  final probe = SignalProbe();
  final relay = PulseRelay(vault, enabled: productionServicesReady);
  final attribution = TraceSignal(agent);
  final router = DriftRouter(
    vault: vault,
    probe: probe,
    attribution: attribution,
    dispatch: GateDispatch(agent, vault),
    relay: relay,
    agent: agent,
    runtimeEnabled: DriftGateConfig.grayCredentialsReady,
  );

  // ── White part (game) init ────────────────────────────────────────────
  final gs = GameState();
  await gs.load();

  runApp(NeonDriftApp(gameState: gs, router: router));
}

class NeonDriftApp extends StatefulWidget {
  final GameState gameState;
  final DriftRouter? router;
  const NeonDriftApp({super.key, required this.gameState, this.router});

  @override
  State<NeonDriftApp> createState() => _NeonDriftAppState();
}

class _NeonDriftAppState extends State<NeonDriftApp> {
  @override
  void initState() {
    super.initState();
    widget.gameState.addListener(_syncAudio);
    _syncAudio();
  }

  void _syncAudio() {
    final gs = widget.gameState;
    Audio.I.applySettings(
      sfx: gs.sfxOn,
      music: gs.musicOn,
      sfxVol: gs.sfxVolume,
      musicVol: gs.musicVolume,
      haptics: gs.hapticsOn,
    );
  }

  @override
  void dispose() {
    widget.gameState.removeListener(_syncAudio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: widget.gameState,
      child: MaterialApp(
        title: 'Neon Drift Board',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: DriftBootScreen(router: widget.router),
        routes: {
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}
