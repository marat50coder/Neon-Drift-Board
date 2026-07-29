import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio.dart';
import 'data/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final gs = GameState();
  await gs.load();
  
  runApp(NeonDriftApp(gameState: gs));
}

class NeonDriftApp extends StatefulWidget {
  final GameState gameState;
  const NeonDriftApp({super.key, required this.gameState});

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
        home: const LoadingScreen(),
        routes: {
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}
