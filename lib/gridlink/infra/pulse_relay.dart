import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'drift_vault.dart';

@pragma('vm:entry-point')
Future<void> ndbBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging + APNs owner. Bootstraps the token, surfaces push
/// destination URLs, and re-fires the config POST on token refresh.
class PulseRelay {
  PulseRelay(this._vault, {required this.enabled});

  final DriftVault _vault;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;
  bool _apnsAvailable = false;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// True only if the OS actually handed us an APNs device token during
  /// [boot]. If Push is not configured (missing aps-environment entitlement,
  /// simulator, revoked provisioning), this stays false and callers must
  /// treat the whole push subsystem as unavailable — no permission prompt,
  /// no token upload — so users are never asked to allow a feature that
  /// physically cannot deliver anything.
  bool get apnsAvailable => _apnsAvailable;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    final initialUrl = initial == null ? null : _extract(initial.data);
    if (initialUrl != null) await _vault.stashPushUrl(initialUrl);

    FirebaseMessaging.onBackgroundMessage(ndbBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _extract(message.data);
      if (url == null) return;
      final callback = onDestination;
      if (callback == null) {
        _vault.stashPushUrl(url);
      } else {
        callback(url);
      }
    });
    await _waitForApns();
    if (!_apnsAvailable) return;
    try {
      _token = await messaging.getToken();
    } catch (_) {
      _token = null;
    }
  }

  String? _extract(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApns({int attempts = 6}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final token = await messaging.getAPNSToken();
        if (token != null && token.isNotEmpty) {
          _apnsAvailable = true;
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
  }

  Future<bool> canOfferPermission() async {
    // Note: this deliberately does NOT gate on [_apnsAvailable]. Showing the
    // permission invite is a gray-flow UX contract; whether APNs delivers a
    // token is a separate concern handled asynchronously in the background
    // token fetch. When APNs is not configured we still show the invite,
    // the OS dialog still records the user's choice, and the portal opens
    // right after without waiting for a token that will never arrive.
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    NotificationSettings result;
    try {
      result = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {
      // A missing aps-environment entitlement can turn the request into a
      // throw on some iOS versions; never let it hang the invite screen.
      return false;
    }
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    // Kick off APNs token acquisition in the background. Do NOT await it —
    // we must NEVER block the invite screen (and by extension the portal
    // handoff) on APNs, because when the entitlement is missing the token
    // fetch never resolves and the user sees a 30s spinner. If the token
    // does arrive, [onTokenChanged] pushes it to the backend on its own.
    if (accepted) unawaited(_fetchTokenAfterGrant());
    return accepted;
  }

  Future<void> _fetchTokenAfterGrant() async {
    try {
      await _waitForApns(attempts: 8);
      if (!_apnsAvailable) return;
      final messaging = _messaging;
      if (messaging == null) return;
      final token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 6));
      if (token == null || token.isEmpty) return;
      _token = token;
      onTokenChanged?.call(token);
    } catch (_) {
      // Silent — token fetch is best-effort.
    }
  }
}
