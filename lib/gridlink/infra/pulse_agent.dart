import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/drift_gate_config.dart';

/// HTTP client whose User-Agent looks like a real Mobile Safari on the actual
/// device. The SAME UA is applied to the WebView (see NeonPortal) so the
/// partner backend sees a consistent client.
class PulseAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.6';
    return parts.join('.');
  }

  // GAME THEME CATEGORY: crash (NO appid/appname suffix appended).
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) '
        'AppleWebKit/${DriftGateConfig.webKitVersion} (KHTML, like Gecko) '
        'Version/${DriftGateConfig.safariVersion} Mobile/15E148 '
        'Safari/${DriftGateConfig.safariTail}';
  }

  String _fallback() => _mobileSafari('18.6');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
