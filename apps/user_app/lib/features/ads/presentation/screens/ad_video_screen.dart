import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// What the route needs to open a banner's video.
class AdVideoArgs {
  final String url;
  final String title;

  const AdVideoArgs({required this.url, required this.title});
}

/// Builds the page that actually plays [url]. A seam for tests: the real
/// WebView needs a platform implementation that widget tests don't have.
typedef AdVideoViewBuilder = Widget Function(String url);

/// Plays a banner's video in an in-app web view — the video lives on an
/// external host (YouTube, Vimeo, a CDN page), we only keep the link.
class AdVideoScreen extends StatelessWidget {
  const AdVideoScreen({super.key, required this.args, this.viewBuilder = _webView});

  final AdVideoArgs args;
  final AdVideoViewBuilder viewBuilder;

  /// Only https is allowed to load or to be navigated to: the link came from
  /// the backend (which already requires https), and a page that redirects the
  /// player to `http:`/`intent:`/`file:` must not be followed.
  static bool isAllowed(String url) => Uri.tryParse(url)?.scheme == 'https';

  static Widget _webView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              isAllowed(request.url) ? NavigationDecision.navigate : NavigationDecision.prevent,
        ),
      )
      ..loadRequest(Uri.parse(url));
    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: Text(args.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: isAllowed(args.url)
          ? viewBuilder(args.url)
          : Center(child: Icon(Symbols.link_off_rounded, size: 48, color: colors.textTertiary)),
    );
  }
}
