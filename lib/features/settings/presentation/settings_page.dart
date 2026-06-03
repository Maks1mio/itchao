import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../data/models.dart';
import '../../auth/auth_controller.dart';
import '../../collections/collections_controller.dart';
import '../settings_account_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(settingsAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(settingsAccountProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: account.when(
        data: (info) {
          if (info == null) {
            return const Center(child: Text('Не выполнен вход'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(profile: info.profile),
              const SizedBox(height: 20),
              Text('Доступ приложения', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Тип: ${info.credentials.type}'
                '${info.credentials.expiresAt != null ? ' · истекает ${info.credentials.expiresAt}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final scope in kRecommendedScopes)
                    _ScopeChip(
                      scope: scope,
                      granted: hasScope(info.credentials.scopes, scope),
                    ),
                  for (final scope in info.credentials.scopes)
                    if (!kRecommendedScopes.contains(scope))
                      _ScopeChip(scope: scope, granted: true),
                ],
              ),
              const SizedBox(height: 24),
              Text('Коллекции (полный доступ)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'OAuth (см. OAuth Applications.md) даёт profile:collections — только список. '
                'Обложки игр в полосах — endpoint collection-games; на ПК itch ходит через butler '
                '(полный доступ), в REST API — только unscoped API key (Serverside API). '
                'Создай ключ на itch.io и вставь ниже.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://itch.io/user/settings/api-keys'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Открыть itch.io → API keys'),
                ),
              ),
              const SizedBox(height: 8),
              _FullApiKeyField(
                onSaved: () {
                  ref.invalidate(collectionsControllerProvider);
                },
              ),
              const SizedBox(height: 24),
              Text('Отладка', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Токен даёт доступ к API. Не публикуй его в открытых чатах.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: info.token));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Токен скопирован в буфер обмена')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать токен'),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  ref.invalidate(settingsAccountProvider);
                  if (context.mounted) {
                    context.go('/gate');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
              ),
            ],
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
                FilledButton(
                  onPressed: () => ref.invalidate(settingsAccountProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundImage: profile.coverUrl != null ? NetworkImage(profile.coverUrl!) : null,
          child: profile.coverUrl == null ? const Icon(Icons.person, size: 36) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'ID: ${profile.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullApiKeyField extends ConsumerStatefulWidget {
  const _FullApiKeyField({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_FullApiKeyField> createState() => _FullApiKeyFieldState();
}

class _FullApiKeyFieldState extends ConsumerState<_FullApiKeyField> {
  final _controller = TextEditingController();
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await ref.read(authControllerProvider.notifier).readFullApiKey();
    if (!mounted) {
      return;
    }
    _controller.text = key ?? '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Полный API key',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final key = _controller.text.trim();
                  if (key.isEmpty) {
                    return;
                  }
                  await ref.read(authControllerProvider.notifier).saveFullApiKey(key);
                  final oauth = await ref.read(authControllerProvider.notifier).readApiKey();
                  var ok = false;
                  if (oauth != null && oauth.isNotEmpty) {
                    final collections = await ref
                        .read(itchApiClientProvider)
                        .fetchCollections(token: oauth);
                    if (collections.isNotEmpty) {
                      ok = await ref.read(itchApiClientProvider).probeCollectionGamesAccess(
                        token: key,
                        collectionId: collections.first.id,
                      );
                    }
                  }
                  widget.onSaved();
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'API key сохранён — обложки коллекций должны загрузиться'
                            : 'API key сохранён, но collection-games недоступен — проверь ключ',
                      ),
                    ),
                  );
                },
                child: const Text('Сохранить'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).saveFullApiKey(null);
                _controller.clear();
                widget.onSaved();
              },
              child: const Text('Очистить'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.scope, required this.granted});

  final String scope;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        granted ? Icons.check_circle : Icons.cancel_outlined,
        size: 18,
        color: granted ? ItchColors.success : Theme.of(context).colorScheme.error,
      ),
      label: Text(scope),
      backgroundColor: granted
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
    );
  }
}
