import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/drift_gate_config.dart';
import 'pulse_agent.dart';

/// Debug-only trace helper. The closure AND its string literals are stripped
/// from release builds by the assert.
void ndbTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}

/// AppsFlyer attribution: warm up, await conversion + deep-link, and compose
/// the flat config-request body (attribution verbatim + device fields).
class TraceSignal {
  TraceSignal(this._agent);

  final PulseAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!DriftGateConfig.grayCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: DriftGateConfig.appsFlyerKey,
          appId: DriftGateConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 4,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flat(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      ndbTrace(() => '[NDB.TRACE] initialization failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      // AppsFlyer delivers a {status:failure,...} map when it can't reach its
      // servers (e.g. an ad-blocking VPN). Never merge that error map in.
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      ndbTrace(
        () => '[NDB.TRACE] conversion status=$status '
            'af_status=${received['af_status']} keys=${received.keys.toList()}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future<void>.delayed(
          const Duration(seconds: DriftGateConfig.organicRecheckSeconds),
        );
        _install = await _fetchGcd() ?? received;
      } else {
        _install = received;
      }
    } catch (error) {
      ndbTrace(() => '[NDB.TRACE] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD uses the numeric App Store id, not the bundle id.
      final base = DriftGateConfig.gcdBase;
      final sep = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${sep}app_id=${DriftGateConfig.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${DriftGateConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    // Non-organic attribution is delivered by AppsFlyer through the same
    // conversion callback that is gated by ATT authorization + DDL/GCD
    // network fetch. If the user is slow to tap the ATT dialog we must not
    // proceed with an empty _install (that would look organic to the gate).
    Duration installTimeout = const Duration(seconds: 30),
    Duration deepLinkTimeout = const Duration(seconds: 12),
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(installTimeout, onTimeout: () {}),
      _deepLinkReady.future.timeout(deepLinkTimeout, onTimeout: () {}),
    ]);
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    if (_reopen != null) {
      _reopen!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = DriftGateConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = DriftGateConfig.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        DriftGateConfig.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = DriftGateConfig.firebaseProjectNumber;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }
    ndbTrace(() => '[NDB.TRACE] payload ${jsonEncode(body)}');
    return body;
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
