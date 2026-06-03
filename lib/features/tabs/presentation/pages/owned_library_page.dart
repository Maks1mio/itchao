import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_controller.dart';
import '../../../library/library_controller.dart';
import '../../../settings/settings_account_provider.dart';
import '../widgets/itch_game_card.dart';

class OwnedLibraryPage extends ConsumerStatefulWidget {
  const OwnedLibraryPage({super.key});

  @override
  ConsumerState<OwnedLibraryPage> createState() => _OwnedLibraryPageState();
}

class _OwnedLibraryPageState extends ConsumerState<OwnedLibraryPage> {
  String? _scopeHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    await ref.read(libraryControllerProvider.notifier).refresh();
    final token = await ref.read(authControllerProvider.notifier).readApiKey();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final credentials = await ref.read(itchApiClientProvider).fetchCredentialInfo(token: token);
      if (!hasScope(credentials.scopes, 'profile:owned')) {
        setState(() {
          _scopeHint = 'Нет доступа profile:owned. Выйдите и войдите снова через OAuth.';
        });
      } else {
        setState(() => _scopeHint = null);
      }
    } catch (_) {
      setState(() => _scopeHint = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryControllerProvider);
    return library.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Купленные игры не найдены'),
                  if (_scopeHint != null) ...[
                    const SizedBox(height: 12),
                    Text(_scopeHint!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Обновить'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/gate');
                      }
                    },
                    child: const Text('Перелогиниться'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Купленные',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ItchGameCard(game: items[index]),
                  childCount: items.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
            ],
          ),
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
