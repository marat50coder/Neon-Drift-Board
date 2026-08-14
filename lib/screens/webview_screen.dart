import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Displays a legal / support page. The white game is 100 % offline: this
/// screen ALWAYS renders the bundled HTML asset and never attempts a network
/// request. The [url] parameter is retained for compatibility (and shown in a
/// mailto link inside the asset itself) but is intentionally NOT fetched, so
/// the app never asks the OS for connectivity and never surfaces a "No
/// Internet Connection" error dialog on airplane / metered / restricted
/// networks.
class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final String assetFallback;
  final Color accent;

  const WebViewScreen({
    super.key,
    required this.title,
    // ignore: unused_element_parameter
    this.url = '',
    required this.assetFallback,
    this.accent = AppColors.cyan,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

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
          onNavigationRequest: (req) {
            if (req.url.startsWith('mailto:')) {
              launchUrl(Uri.parse(req.url),
                  mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            // Block outbound HTTP(S) navigation — the game is fully offline.
            // The bundled asset must contain all needed content inline.
            if (req.url.startsWith('http://') ||
                req.url.startsWith('https://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
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
                      _controller.loadFlutterAsset(widget.assetFallback);
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
