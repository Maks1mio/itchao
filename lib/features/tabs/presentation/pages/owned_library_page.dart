import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models.dart';
import '../../../auth/auth_controller.dart';
import '../../../install/installed_games_controller.dart';
import '../../../install/installed_library_games.dart';
import '../../../library/library_controller.dart';
import '../../../settings/settings_account_provider.dart';
import '../widgets/library_game_stripe.dart';

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
    await ref.read(installedGamesProvider.notifier).discoverFromDevice();
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

  List<LibraryGame> _installedGames(List<LibraryGame> libraryItems) {
    final installed = ref.watch(installedGamesProvider);
    return buildInstalledLibraryGames(
      installed: installed,
      library: libraryItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(installedGamesProvider);
    final library = ref.watch(libraryControllerProvider);
    return library.when(
      data: (items) {
        final installed = _installedGames(items);
        if (items.isEmpty && installed.isEmpty) {
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
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            children: [
              if (_scopeHint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    _scopeHint!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              LibraryGameStripe(
                title: 'Купленные',
                games: items,
                showAllUrl: 'itch://library/purchased',
                showAllLabel: 'Купленные',
              ),
              LibraryGameStripe(
                title: 'Установленные',
                games: installed,
                showAllUrl: 'itch://library/installed',
                showAllLabel: 'Установленные',
              ),
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
