import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/web/itch_webview.dart';
import '../auth_controller.dart';
import '../oauth_config.dart';

class OAuthWebLoginPage extends ConsumerStatefulWidget {
  const OAuthWebLoginPage({super.key});

  @override
  ConsumerState<OAuthWebLoginPage> createState() => _OAuthWebLoginPageState();
}

class _OAuthWebLoginPageState extends ConsumerState<OAuthWebLoginPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _currentUrl = OAuthConfig.loginUri().toString();
  var _handlingCallback = false;

  @override
  void initState() {
    super.initState();
    _controller = ItchWebView.create(
      onUrlChanged: (url) {
        if (mounted) {
          setState(() => _currentUrl = url);
        }
        _tryHandleOAuthCallback(url);
      },
      onLoadingChanged: (loading) {
        if (mounted) {
          setState(() => _isLoading = loading);
        }
      },
      onNavigationUrl: (url) {
        return _tryHandleOAuthCallback(url);
      },
    )..loadRequest(OAuthConfig.loginUri());
  }

  bool _tryHandleOAuthCallback(String url) {
    if (_handlingCallback) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final isCallback = uri.scheme == OAuthConfig.callbackScheme &&
        uri.host == 'oauth' &&
        uri.path == '/callback';
    if (!isCallback) {
      return false;
    }
    _handlingCallback = true;
    Future.microtask(() async {
      final profile = await ref
          .read(authControllerProvider.notifier)
          .completeOAuthCallback(uri);
      if (!mounted) {
        return;
      }
      if (profile != null) {
        // Закрепляем cookies itch.io для загрузки обложек коллекций без API key.
        await _controller.loadRequest(Uri.parse('https://itch.io/'));
        if (!mounted) {
          return;
        }
        context.go('/tabs');
      } else {
        setState(() => _handlingCallback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось завершить вход')),
        );
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход через itch.io'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/gate'),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Войдите в аккаунт itch.io — сессия сохранится в приложении.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_isLoading || authState.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
