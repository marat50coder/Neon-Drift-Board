import 'dart:async';
import 'dart:io';

import 'config/drift_gate_config.dart';
import 'core/link_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/drift_vault.dart';
import 'infra/gate_dispatch.dart';
import 'infra/pulse_relay.dart';
import 'infra/pulse_agent.dart';
import 'infra/signal_probe.dart';
import 'infra/trace_signal.dart';

/// The whole gray/white routing brain. Runs once per boot; the boot screen
/// renders the loading art while [decide] resolves the destination.
class DriftRouter {
  DriftRouter({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.dispatch,
    required this.relay,
    required this.agent,
    required this.runtimeEnabled,
  });

  final DriftVault vault;
  final SignalProbe probe;
  final TraceSignal attribution;
  final GateDispatch dispatch;
  final PulseRelay relay;
  final PulseAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && DriftGateConfig.grayCredentialsReady;

  Future<LaneTarget>? _decideFuture;

  /// De-duplicates only *concurrent* calls (the boot screen can build twice),
  /// then clears the cache so a later Retry re-runs the full pipeline instead
  /// of replaying a cached DarkLane.
  Future<LaneTarget> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<LaneTarget> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      ndbTrace(
        () => '[NDB.ROUTER] gate disabled runtime=$runtimeEnabled '
            'creds=${DriftGateConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const NativeLane();
    }

    ndbTrace(() => '[NDB.ROUTER] decide start route=${vault.route}');

    relay.onTokenChanged = _refreshForToken;
    // Cold-start push tap is consumed FIRST, before anything else.
    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(DriftLane.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalLane(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      DriftLane.undecided => _firstDecision(onProgress),
      DriftLane.portal => _returningPortal(onProgress),
      DriftLane.native => _returningNative(onProgress),
    };
  }

  Future<LaneTarget> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      ndbTrace(() => '[NDB.ROUTER] first: no interface -> offline');
      return const DarkLane(returnToNative: false);
    }
    progress(0.28);
    try {
      await relay.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      ndbTrace(() => '[NDB.ROUTER] first: DNS probe failed -> offline');
      return const DarkLane(returnToNative: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    ndbTrace(
      () => '[NDB.ROUTER] first: config hasDest=${reply.hasDestination}',
    );
    if (reply.hasDestination) {
      await vault.saveRoute(DriftLane.portal);
      return PortalLane(reply.url!);
    }
    await vault.saveRoute(DriftLane.native);
    return const NativeLane();
  }

  Future<LaneTarget> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const DarkLane(returnToNative: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalLane(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalLane(cached);
    }

    await Future.wait<void>(<Future<void>>[
      relay.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const DarkLane(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalLane(reply.url!);
    if (cached != null) return PortalLane(cached);
    return const DarkLane(returnToNative: false);
  }

  Future<LaneTarget> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeLane();
    }
    await Future.wait<void>(<Future<void>>[
      relay.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeLane();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeLane();
    await vault.saveRoute(DriftLane.portal);
    return PortalLane(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? relay.token,
    );
    return dispatch.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        relay.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
