import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/drift_gate_config.dart';
import '../infra/drift_vault.dart';
import '../infra/pulse_relay.dart';

const String _hBg =
    'assets/Neon_Drift_Board_additional_assets/Horizontal_Notifications_Screen.webp';
const String _vBg =
    'assets/Neon_Drift_Board_additional_assets/Vertical_Notifications_Screen.webp';

/// Push opt-in promo, shown before the portal on first entry into gray mode.
class PulseInvitation extends StatefulWidget {
  const PulseInvitation({
    super.key,
    required this.vault,
    required this.relay,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final DriftVault vault;
  final PulseRelay relay;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PulseInvitation> createState() => _PulseInvitationState();
}

class _PulseInvitationState extends State<PulseInvitation> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Boot locks portrait before routing here; re-enable landscape so the
    // invite screen rotates with the device (matches the portal).
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    var granted = false;
    try {
      granted = await widget.relay.askPermission();
      final token = widget.relay.token;
      if (granted && token != null && token.isNotEmpty) {
        await widget.onTokenReady?.call(token);
      }
    } catch (_) {
      // askPermission must never trap the user on a spinner; treat any
      // failure as "not granted" and move on to the portal.
      granted = false;
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        DriftGateConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape ? _hBg : _vBg;
    // Landscape: centred horizontally with NO safe-area so the notch never
    // shifts the horizontal centre.
    final width = landscape
        ? (media.size.width * 0.42).clamp(320.0, 560.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);
    final acceptH = landscape ? 66.0 : 74.0;
    final skipH = landscape ? 58.0 : 64.0;
    final acceptFont = landscape ? 22.0 : 25.0;
    final skipFont = landscape ? 20.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PulseButton(
                  width: width,
                  height: acceptH,
                  fontSize: acceptFont,
                  label: 'Allow',
                  emphasized: true,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                _PulseButton(
                  width: width * 0.9,
                  height: skipH,
                  fontSize: skipFont,
                  label: 'Skip',
                  emphasized: false,
                  busy: false,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseButton extends StatelessWidget {
  const _PulseButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFF23F0FF), Color(0xFFB14BFF)]
                : const <Color>[Color(0xFF3A4270), Color(0xFF232A52)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF0A1030), width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: emphasized ? const Color(0x8823F0FF) : Colors.black45,
              blurRadius: emphasized ? 18 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF0A1030),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: emphasized
                            ? const Color(0xFF0A1030)
                            : Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
