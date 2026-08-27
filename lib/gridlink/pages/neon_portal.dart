import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/drift_vault.dart';
import '../infra/pulse_agent.dart';
import '../infra/pulse_relay.dart';
import '../infra/signal_probe.dart';
import 'dead_signal_page.dart';

/// Full-screen WKWebView shell that hosts the partner URL for non-organic
/// users. Handles safe area, offline, rotation reflow, redirect loops,
/// cold-start viewport settle and native-feel JS injections.
class NeonPortal extends StatefulWidget {
  const NeonPortal({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.relay,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final DriftVault vault;
  final SignalProbe probe;
  final PulseRelay relay;
  final PulseAgent agent;
  final bool coldLaunch;

  @override
  State<NeonPortal> createState() => _NeonPortalState();
}

class _NeonPortalState extends State<NeonPortal> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.relay.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (!mounted || uri == null || !uri.hasScheme) return;
      // Claim the vault copy so a later resume-drain does not reload the
      // same page (PulseRelay stashes first, then invokes this callback).
      unawaited(widget.vault.consumePushUrl());
      _controller.loadRequest(uri);
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        // Definitively offline — show it immediately, no DNS probe first.
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive settle in the ACTUAL orientation before mounting, so
    // WKWebView measures the correct viewport. No landscape nudge here.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(const <int>[40, 160, 320, 560, 850]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomHold();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installInsetGuard();
        _installZoomHold();
        _installTapClean();
        _installInputRaise();
        _installFocusFix();
        _installInlinePlay();
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installInsetGuard();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 = cancelled (a new navigation superseded this one).
        if (error.errorCode == -999) return;
        // WKWebView sometimes reports isForMainFrame as null for the main
        // navigation — treat null as main-frame so a real load failure is
        // never silently swallowed.
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 3) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  /// Confirms an outage with a reachability probe (WebView load errors can be
  /// transient) before routing to the offline screen.
  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  /// Routes to the offline screen immediately (no probe).
  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DeadSignalPage(
          probe: widget.probe,
          retryBuilder: (_) => NeonPortal(
            url: current,
            vault: widget.vault,
            probe: widget.probe,
            relay: widget.relay,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  void _installInsetGuard() {
    _controller.runJavaScript(r'''
(() => {
  const root = window;
  if (root.__ndbInsetGuard) return;
  root.__ndbInsetGuard = true;
  const sheetId = 'ndb-inset-sheet';
  const cssRules = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}'
  ].join('');
  const kbUp = () => {
    const vv = root.visualViewport;
    return !!vv && vv.height < root.innerHeight * 0.75;
  };
  const apply = () => {
    if (kbUp()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(meta);
    } else {
      const clean = (meta.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.content = `${clean}${clean ? ', ' : ''}viewport-fit=contain`;
    }
    let sheet = document.getElementById(sheetId);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = sheetId;
      host.appendChild(sheet);
    }
    sheet.textContent = cssRules;
  };
  const later = () => {
    root.setTimeout(apply, 170);
    root.setTimeout(apply, 640);
  };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      later();
      return result;
    };
  });
  root.addEventListener('popstate', later);
  apply();
  root.setInterval(apply, 2900);
})();
''');
  }

  void _installZoomHold() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ndbZoomHold) return;
  window.__ndbZoomHold = true;
  const lockMeta = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };
  lockMeta();
  const block = (e) => { e.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((t) =>
    document.addEventListener(t, block, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTap = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTap <= 300) e.preventDefault();
    lastTap = now;
  }, {passive: false});
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      setTimeout(lockMeta, 150);
      return result;
    };
  });
  window.addEventListener('popstate', () => setTimeout(lockMeta, 150));
})();
''');
  }

  void _installTapClean() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ndbTapClean) return;
  window.__ndbTapClean = true;
  const style = document.createElement('style');
  style.id = 'ndb-tap-clean';
  style.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installInputRaise() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ndbInputRaise) return;
  window.__ndbInputRaise = true;
  const canEdit = (node) => !!node && (
    node.matches?.('input, textarea, select, [contenteditable="true"]')
  );
  const raise = () => {
    const active = document.activeElement;
    if (!canEdit(active)) return;
    active.scrollIntoView({behavior: 'auto', block: 'nearest'});
  };
  document.addEventListener('focusin', (event) => {
    if (canEdit(event.target)) window.setTimeout(raise, 350);
  }, true);
})();
''');
  }

  void _installFocusFix() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(() => {
  if (window.__ndbFocusFix) return;
  window.__ndbFocusFix = true;
  const style = document.createElement('style');
  style.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installInlinePlay() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ndbInlinePlay) return;
  window.__ndbInlinePlay = true;
  const wake = (video) => {
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    const p = video.play();
    if (p?.catch) p.catch(() => {});
  };
  const scan = (node) => {
    if (node instanceof HTMLVideoElement) wake(node);
    node.querySelectorAll?.('video').forEach(wake);
  };
  scan(document);
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach(scan));
  }).observe(document.documentElement, {childList: true, subtree: true});
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.relay.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
