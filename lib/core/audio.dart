import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Central sound effect + music manager. Everything plays from bundled assets,
/// so it works fully offline.
class Audio {
  Audio._();
  static final Audio I = Audio._();

  static const String _base = 'Neon_Drift_Board_sounds_assets/';

  final List<AudioPlayer> _sfxPool = [];
  int _poolIndex = 0;
  AudioPlayer? _music;

  bool sfxOn = true;
  bool musicOn = true;
  double sfxVolume = 0.8;
  double musicVolume = 0.5;
  bool hapticsOn = true;

  String? _currentMusic;

  static const Map<String, String> sfx = {
    'click': '${_base}interface_click_asset.mp3',
    'open': '${_base}interface_opening_asset.mp3',
    'sphere': '${_base}energy_pickup_asset.mp3',
    'crystal': '${_base}rare_collectible_sphere_asset.mp3',
    'boost': '${_base}Boost_Pad_asset.mp3',
    'turbo': '${_base}turbo_activation_asset.mp3',
    'turbo_off': '${_base}Short_futuristic_turbo_shutdown_asset.mp3',
    'jump': '${_base}hoverboard_jump_asset.mp3',
    'land': '${_base}landing_asset.mp3',
    'drift': '${_base}hoverboard_drift_asset.mp3',
    'hit': '${_base}hit_small_asset.mp3',
    'crash': '${_base}strong_hit_asset.mp3',
    'gate': '${_base}portal_activation_asset.mp3',
    'checkpoint': '${_base}checkpoint_activation_asset.mp3',
    'delivery': '${_base}successful_delivery_confirmation_asset.mp3',
    'victory': '${_base}victory_jingle_asset.mp3',
    'fail': '${_base}failure_jingle_asset.mp3',
    'police': '${_base}Police_Detection_asset.mp3',
  };

  static const String gameMusic =
      '${_base}Continuous_futuristic_turbo_propulsion_asset.mp3';

  Future<void> init() async {
    for (var i = 0; i < 5; i++) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _sfxPool.add(p);
    }
    _music = AudioPlayer();
    await _music!.setReleaseMode(ReleaseMode.loop);
  }

  void applySettings({
    required bool sfx,
    required bool music,
    required double sfxVol,
    required double musicVol,
    required bool haptics,
  }) {
    sfxOn = sfx;
    musicOn = music;
    sfxVolume = sfxVol;
    musicVolume = musicVol;
    hapticsOn = haptics;
    _music?.setVolume(musicVolume);
    if (!musicOn) {
      _music?.pause();
    } else if (_currentMusic != null) {
      _music?.resume();
    }
  }

  Future<void> play(String name, {double volumeScale = 1.0}) async {
    if (!sfxOn) return;
    final path = sfx[name];
    if (path == null) return;
    final player = _sfxPool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.play(AssetSource(path),
          volume: (sfxVolume * volumeScale).clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> startGameMusic() async {
    if (!musicOn) return;
    if (_currentMusic == gameMusic) {
      await _music?.resume();
      return;
    }
    _currentMusic = gameMusic;
    try {
      await _music?.setVolume(musicVolume * 0.6);
      await _music?.play(AssetSource(gameMusic), volume: musicVolume * 0.6);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _currentMusic = null;
    try {
      await _music?.stop();
    } catch (_) {}
  }

  void haptic() {
    if (hapticsOn) HapticFeedback.lightImpact();
  }

  void heavyHaptic() {
    if (hapticsOn) HapticFeedback.heavyImpact();
  }
}
