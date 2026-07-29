import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Displays a legal / support page. Loads the live URL when online and falls
/// back to a bundled, black-on-white local copy when offline, so the content
/// is ALWAYS available (fully offline capable).
class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final String assetFallback;
  final Color accent;

  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
    required this.assetFallback,
    this.accent = AppColors.cyan,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _usedFallback = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Any failure -> show the offline bundled copy.
            if (!_usedFallback && err.errorType != null) {
              _loadFallback();
            }
          },
          onNavigationRequest: (req) {
            if (req.url.startsWith('mailto:')) {
              launchUrl(Uri.parse(req.url),
                  mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _start();
  }

  Future<void> _start() async {
    final conn = await Connectivity().checkConnectivity();
    final online = !conn.contains(ConnectivityResult.none);
    if (online) {
      _controller.loadRequest(Uri.parse(widget.url));
    } else {
      _loadFallback();
    }
  }

  void _loadFallback() {
    _usedFallback = true;
    _controller.loadFlutterAsset(widget.assetFallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TopBar(
                title: widget.title,
                accent: widget.accent,
                actions: [
                  NeonIconButton(
                    icon: Icons.refresh_rounded,
                    color: widget.accent,
                    onTap: () {
                      setState(() => _loading = true);
                      _usedFallback = false;
                      _start();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: widget.accent.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_loading)
                      Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(color: widget.accent),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
