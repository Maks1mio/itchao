import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/itch_colors.dart';
import '../../../../core/web/itch_webview.dart';
import '../../browsing_history_controller.dart';
import '../../itch_url.dart';
import '../../tabs_controller.dart';
import '../tab_back_handler_provider.dart';
import '../tab_chrome_provider.dart';

class ItchBrowserPage extends ConsumerStatefulWidget {
  const ItchBrowserPage({
    required this.initialUrl,
    this.belowHubChrome = false,
    super.key,
  });

  final String initialUrl;

  /// Внутри [ItchTabBody] — без дублирования отступа (уже есть padding сверху).
  final bool belowHubChrome;

  @override
  ConsumerState<ItchBrowserPage> createState() => _ItchBrowserPageState();
}

class _ItchBrowserPageState extends ConsumerState<ItchBrowserPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _canGoBack = false;
  var _canGoForward = false;
  var _canPopTab = false;
  late String _currentUrl;
  String? _lastRecordedUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _controller = ItchWebView.create(
      onUrlChanged: _onUrlChanged,
      onLoadingChanged: (loading) {
        setState(() => _isLoading = loading);
        if (!loading) {
          unawaited(_updateNavState());
        }
      },
    )..loadRequest(Uri.parse(widget.initialUrl));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindChrome());
  }

  @override
  void dispose() {
    final back = ref.read(tabBackHandlerProvider.notifier);
    final chrome = ref.read(tabChromeProvider.notifier);
    super.dispose();
    Future.microtask(() {
      back.state = null;
      chrome.clearPageMenu(showTitle: true);
    });
  }

  void _bindChrome() {
    if (!mounted) {
      return;
    }
    _canPopTab = ref.read(tabsControllerProvider.notifier).canPopActiveTab();
    ref.read(tabChromeProvider.notifier).clearPageMenu(showTitle: false);
    ref.read(tabBackHandlerProvider.notifier).state = _handleSystemBack;
    setState(() {});
  }

  Future<bool> _handleSystemBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _updateNavState();
      return true;
    }
    return false;
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _updateNavState();
      return;
    }
    if (ref.read(tabsControllerProvider.notifier).popActiveTab()) {
      return;
    }
  }

  Future<void> _goForward() async {
    await _controller.goForward();
    await _updateNavState();
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
      _canPopTab = ref.read(tabsControllerProvider.notifier).canPopActiveTab();
    });
  }

  Future<void> _loadUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final uri = trimmed.contains('://') ? Uri.parse(trimmed) : Uri.parse('https://$trimmed');
    await _controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
        _BrowserBottomBar(
          url: _currentUrl,
          canGoBack: _canGoBack || _canPopTab,
          canGoForward: _canGoForward,
          onBack: _goBack,
          onForward: _goForward,
          onReload: () => _controller.reload(),
          onSubmitUrl: _loadUrl,
          bottomInset: viewInsets.bottom > 0 ? viewInsets.bottom : padding.bottom,
        ),
      ],
    );
  }
}

class _BrowserBottomBar extends StatefulWidget {
  const _BrowserBottomBar({
    required this.url,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onSubmitUrl,
    required this.bottomInset,
  });

  final String url;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final ValueChanged<String> onSubmitUrl;
  final double bottomInset;

  @override
  State<_BrowserBottomBar> createState() => _BrowserBottomBarState();
}

class _BrowserBottomBarState extends State<_BrowserBottomBar> {
  late final TextEditingController _urlController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url);
  }

  @override
  void didUpdateWidget(covariant _BrowserBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && _urlController.text != widget.url) {
      _urlController.text = widget.url;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ItchColors.bread,
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + widget.bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              focusNode: _focusNode,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: const TextStyle(color: ItchColors.ivory, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Адрес',
                filled: true,
                fillColor: ItchColors.item,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: widget.onSubmitUrl,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: widget.canGoBack ? widget.onBack : null,
                  icon: const Icon(Icons.arrow_back),
                  color: ItchColors.ivory,
                  tooltip: 'Назад',
                ),
                IconButton(
                  onPressed: widget.canGoForward ? widget.onForward : null,
                  icon: const Icon(Icons.arrow_forward),
                  color: ItchColors.ivory,
                  tooltip: 'Вперёд',
                ),
                IconButton(
                  onPressed: widget.onReload,
                  icon: const Icon(Icons.refresh),
                  color: ItchColors.ivory,
                  tooltip: 'Обновить',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
