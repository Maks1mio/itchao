import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../core/web/itch_webview.dart';
import '../api_keys/itch_api_keys_parser.dart';
import '../api_keys/itch_api_keys_scripts.dart';
import '../auth_controller.dart';

const _apiKeysUrl = 'https://itch.io/user/settings/api-keys';

class ApiKeysSetupPage extends ConsumerStatefulWidget {
  const ApiKeysSetupPage({super.key});

  @override
  ConsumerState<ApiKeysSetupPage> createState() => _ApiKeysSetupPageState();
}

class _ApiKeysSetupPageState extends ConsumerState<ApiKeysSetupPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _status = 'Загрузка страницы API keys…';
  var _busy = false;
  var _didSubmitCreate = false;
  var _processGeneration = 0;
  Timer? _finishDebounce;

  @override
  void dispose() {
    _finishDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = ItchWebView.create(
      onUrlChanged: (_) {},
      onLoadingChanged: (loading) {
        _safeSetState(() => _isLoading = loading);
      },
      onPageFinished: _onPageFinished,
    )..loadRequest(Uri.parse(_apiKeysUrl));
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  void _setStatus(String message) {
    _safeSetState(() => _status = message);
  }

  void _onPageFinished(String url) {
    if (!url.contains('/user/settings/api-keys')) {
      return;
    }
    _finishDebounce?.cancel();
    _finishDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        unawaited(_processPage());
      }
    });
  }

  Future<void> _processPage() async {
    if (_busy || !mounted) {
      return;
    }
    final generation = ++_processGeneration;
    _busy = true;
    _setStatus('Читаем ключи…');

    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || generation != _processGeneration) {
        return;
      }

      final raw = await _controller.runJavaScriptReturningResult(
        ItchApiKeysScripts.extractKeys,
      );
      if (!mounted || generation != _processGeneration) {
        return;
      }

      final data = parseApiKeysJsonResult(raw);
      if (data == null) {
        _setStatus('Не удалось прочитать страницу. Нажмите «Повторить».');
        return;
      }

      final existing = data.pickDownloadKey();
      if (existing != null) {
        await _saveAndContinue(existing, generation: generation);
        return;
      }

      if (!_didSubmitCreate && data.csrfToken != null) {
        _didSubmitCreate = true;
        _setStatus('Создаём API key (web)…');
        await _controller.runJavaScriptReturningResult(
          ItchApiKeysScripts.submitCreateForm,
        );
        // Страница перезагрузится — ждём следующий onPageFinished, не трогаем context.
        return;
      }

      _setStatus(
        'Нет ключа desktop/web. Нажмите «Generate new API key» на странице '
        '(или введите пароль), затем «Повторить».',
      );
    } catch (e) {
      if (mounted && generation == _processGeneration) {
        _setStatus('Ошибка: $e');
      }
    } finally {
      if (mounted && generation == _processGeneration) {
        _busy = false;
      }
    }
  }

  Future<void> _saveAndContinue(String apiKey, {required int generation}) async {
    await ref.read(authControllerProvider.notifier).saveFullApiKey(apiKey);
    if (!mounted || generation != _processGeneration) {
      return;
    }
    _processGeneration++;
    context.go('/tabs');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ItchColors.background,
      appBar: AppBar(
        backgroundColor: ItchColors.bread,
        title: const Text('API key для загрузок'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (mounted) {
              context.go('/tabs');
            }
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: ItchColors.item,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Шаг 2 из 2',
                    style: TextStyle(
                      color: ItchColors.accentLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'itch.io может попросить пароль — введите его в браузере ниже. '
                    'Берём ключ desktop, иначе web (hitchapp не используем).',
                    style: TextStyle(color: ItchColors.secondaryText, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: const TextStyle(color: ItchColors.ivory, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : () => unawaited(_processPage()),
                        child: const Text('Повторить'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.go('/tabs'),
                        child: const Text('Пропустить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
