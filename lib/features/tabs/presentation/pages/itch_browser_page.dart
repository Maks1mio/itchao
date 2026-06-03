import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/web/itch_webview.dart';
import '../../browsing_history_controller.dart';
import '../../itch_url.dart';
import '../../tabs_controller.dart';

class ItchBrowserPage extends ConsumerStatefulWidget {
  const ItchBrowserPage({required this.initialUrl, super.key});

  final String initialUrl;

  @override
  ConsumerState<ItchBrowserPage> createState() => _ItchBrowserPageState();
}

class _ItchBrowserPageState extends ConsumerState<ItchBrowserPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _canGoBack = false;
  var _canGoForward = false;
  late String _currentUrl;
  String? _lastRecordedUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _controller = ItchWebView.create(
      onUrlChanged: _onUrlChanged,
      onLoadingChanged: (loading) => setState(() => _isLoading = loading),
    )..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _onUrlChanged(String url) {
    if (_currentUrl == url) {
      return;
    }
    setState(() => _currentUrl = url);
    _schedulePersistUrl(url);
  }

  void _schedulePersistUrl(String url) {
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      _persistUrl(url);
    });
  }

  void _persistUrl(String url) {
    if (_lastRecordedUrl == url) {
      return;
    }
    _lastRecordedUrl = url;
    final label = ItchUrl.parse(url).isExternal ? null : ItchUrl.labelFor(url);
    ref.read(browsingHistoryProvider.notifier).record(url, label: label);
    ref.read(tabsControllerProvider.notifier).replaceActiveTabLocation(url, label: label);
  }

  Future<void> _updateNavState() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: _canGoBack
                      ? () async {
                          await _controller.goBack();
                          await _updateNavState();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  onPressed: _canGoForward
                      ? () async {
                          await _controller.goForward();
                          await _updateNavState();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  onPressed: () => _controller.reload(),
                  icon: const Icon(Icons.refresh),
                ),
                Expanded(
                  child: Text(
                    _currentUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: WebViewWidget(
            controller: _controller,
          ),
        ),
      ],
    );
  }
}
