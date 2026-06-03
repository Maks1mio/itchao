import 'package:webview_flutter/webview_flutter.dart';

typedef NavigationUrlHandler = bool Function(String url);

class ItchWebView {
  static WebViewController create({
    required void Function(String url) onUrlChanged,
    void Function(bool isLoading)? onLoadingChanged,
    void Function(String url)? onPageFinished,
    NavigationUrlHandler? onNavigationUrl,
  }) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (onNavigationUrl != null && onNavigationUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            onLoadingChanged?.call(true);
            onUrlChanged(url);
          },
          onPageFinished: (url) {
            onLoadingChanged?.call(false);
            onUrlChanged(url);
            onPageFinished?.call(url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              onUrlChanged(url);
            }
          },
        ),
      );
  }

  static Future<void> clearSession() {
    return WebViewCookieManager().clearCookies();
  }
}
