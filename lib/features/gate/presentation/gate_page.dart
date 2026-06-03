import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/auth_controller.dart';

class GatePage extends ConsumerStatefulWidget {
  const GatePage({super.key});

  @override
  ConsumerState<GatePage> createState() => _GatePageState();
}

class _GatePageState extends ConsumerState<GatePage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (!next.hasValue || next.value == null || !mounted) {
        return;
      }
      Future.microtask(() async {
        final full = await ref.read(authControllerProvider.notifier).readFullApiKey();
        if (!mounted) {
          return;
        }
        if (full == null || full.isEmpty) {
          context.go('/api-keys-setup');
        } else {
          context.go('/tabs');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              '1. Войдите через itch.io (OAuth приложения).\n'
              '2. На следующем шаге откроется страница API keys — '
              'при необходимости введите пароль; ключ для загрузок подтянется автоматически '
              '(сначала desktop, иначе web).',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: authState.isLoading ? null : () => context.push('/oauth-login'),
              child: const Text('Войти через itch.io'),
            ),
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${authState.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
