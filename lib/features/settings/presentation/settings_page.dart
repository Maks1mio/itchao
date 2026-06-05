import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../data/models.dart';
import '../../auth/auth_controller.dart';
import '../../collections/collections_controller.dart';
import '../game_page_browser_mode_provider.dart';
import '../settings_app_info_provider.dart';
import '../settings_account_provider.dart';
import '../ui_inspector_settings_provider.dart';
import 'settings_widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(settingsAccountProvider);

    return Scaffold(
      backgroundColor: ItchColors.background,
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
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: account.when(
        data: (info) {
          if (info == null) {
            return const Center(child: Text('Не выполнен вход'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
            children: [
              const SettingsSectionTitle('Аккаунт'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    active: true,
                    child: _ProfileRow(profile: info.profile),
                  ),
                ],
              ),
              const SettingsSectionTitle('Доступ приложения'),
              SettingsExplanation(
                text: 'Тип: ${info.credentials.type}'
                    '${info.credentials.expiresAt != null ? ' · истекает ${info.credentials.expiresAt}' : ''}',
              ),
              const SizedBox(height: 8),
              SettingsGroup(
                children: [
                  for (final scope in kRecommendedScopes)
                    SettingsCheckRow(
                      label: scope,
                      checked: hasScope(info.credentials.scopes, scope),
                    ),
                  for (final scope in info.credentials.scopes)
                    if (!kRecommendedScopes.contains(scope))
                      SettingsCheckRow(label: scope, checked: true),
                ],
              ),
              const SettingsSectionTitle('Скачивание и установка'),
              const SettingsExplanation(
                text:
                    'OAuth не даёт доступ к файлам. Ключ desktop/web подтягивается при входе '
                    'или кнопкой ниже.',
              ),
              SettingsActionButton(
                icon: Icons.key,
                label: 'Обновить API key автоматически',
                onPressed: () => context.push('/api-keys-setup'),
              ),
              const SettingsSectionTitle('Коллекции'),
              SettingsExplanation(
                text:
                    'Список коллекций — OAuth (profile:collections). Игры в полосах и внутри коллекции — '
                    'REST collection-games (как butler на ПК): нужен полный API key без scope или scope '
                    'collection:view. Создай ключ на itch.io и вставь ниже.',
                child: SettingsLinkRow(
                  label: 'Открыть itch.io → API keys',
                  icon: Icons.open_in_new,
                  onTap: () => launchUrl(
                    Uri.parse('https://itch.io/user/settings/api-keys'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SettingsGroup(
                children: [
                  SettingsRow(
                    child: _FullApiKeyField(
                      onSaved: () {
                        ref.invalidate(collectionsControllerProvider);
                      },
                    ),
                  ),
                ],
              ),
              const SettingsSectionTitle('Дополнительно'),
              _AdvancedSettingsSection(
                oauthToken: info.token,
                credentialsType: info.credentials.type,
              ),
              const SettingsExplanation(
                text: 'Токены дают доступ к API. Не публикуй их в открытых чатах.',
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

class _AdvancedSettingsSection extends ConsumerStatefulWidget {
  const _AdvancedSettingsSection({
    required this.oauthToken,
    required this.credentialsType,
  });

  final String oauthToken;
  final String credentialsType;

  @override
  ConsumerState<_AdvancedSettingsSection> createState() =>
      _AdvancedSettingsSectionState();
}

class _AdvancedSettingsSectionState extends ConsumerState<_AdvancedSettingsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsAppUpdateProvider.notifier).checkNow();
    });
  }

  Future<void> _copyFullApiKey(BuildContext context) async {
    final key = await ref.read(authControllerProvider.notifier).readFullApiKey();
    if (!context.mounted) {
      return;
    }
    _copyToken(context, 'Полный API key', key);
  }

  void _copyToken(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label не сохранён')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label скопирован')),
    );
  }

  String _updateStatusLabel(AppUpdateStatus status, String currentVersion) {
    return switch (status.state) {
      AppUpdateCheckState.idle => 'itchao @ $currentVersion',
      AppUpdateCheckState.checking => 'itchao @ $currentVersion — проверка…',
      AppUpdateCheckState.upToDate =>
        'itchao @ $currentVersion — актуальная версия',
      AppUpdateCheckState.outdated =>
        'itchao @ $currentVersion — доступна ${status.latestVersion}',
      AppUpdateCheckState.unavailable =>
        'itchao @ $currentVersion — ${status.message ?? 'нет данных'}',
      AppUpdateCheckState.failed =>
        'itchao @ $currentVersion — ${status.message ?? 'ошибка проверки'}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final appInfo = ref.watch(settingsAppInfoProvider);
    final update = ref.watch(settingsAppUpdateProvider);
    final browserMode = ref.watch(gamePageBrowserModeProvider);
    final uiInspectorEnabled = ref.watch(uiInspectorEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
          child: Row(
            children: [
              const Icon(Icons.view_list, size: 18, color: ItchColors.secondaryText),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Компоненты',
                  style: TextStyle(color: ItchColors.ivory, fontSize: 14),
                ),
              ),
              InkWell(
                onTap: () => ref.read(settingsAppUpdateProvider.notifier).checkNow(),
                child: const Text(
                  'Проверить обновления',
                  style: TextStyle(
                    color: Color(0xFF87A7C3),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF87A7C3),
                  ),
                ),
              ),
            ],
          ),
        ),
        appInfo.when(
          loading: () => const SettingsGroup(
            children: [
              SettingsInfoRow(
                icon: Icons.check_circle_outline,
                label: 'itchao — загрузка…',
              ),
            ],
          ),
          error: (error, _) => SettingsGroup(
            children: [
              SettingsInfoRow(
                icon: Icons.error_outline,
                label: 'Не удалось загрузить информацию',
                detail: '$error',
              ),
            ],
          ),
          data: (info) {
            final status = update.valueOrNull ?? AppUpdateStatus.initial;
            final updateIcon = switch (status.state) {
              AppUpdateCheckState.outdated => Icons.warning_amber_rounded,
              AppUpdateCheckState.failed || AppUpdateCheckState.unavailable =>
                Icons.info_outline,
              _ => Icons.check_circle_outline,
            };
            final updateColor = switch (status.state) {
              AppUpdateCheckState.outdated => ItchColors.caution,
              AppUpdateCheckState.failed => ItchColors.error,
              AppUpdateCheckState.upToDate => ItchColors.success,
              _ => ItchColors.secondaryText,
            };
            return SettingsGroup(
              children: [
                SettingsRow(
                  active: status.state == AppUpdateCheckState.upToDate,
                  child: Row(
                    children: [
                      Icon(updateIcon, size: 18, color: updateColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_updateStatusLabel(status, info.versionLabel)),
                      ),
                    ],
                  ),
                ),
                SettingsInfoRow(
                  icon: Icons.phone_android,
                  label: info.device.platform,
                  detail: info.device.description,
                ),
                SettingsInfoRow(
                  icon: Icons.vpn_key_outlined,
                  label: 'Тип входа: ${widget.credentialsType}',
                ),
              ],
            );
          },
        ),
        if (update.valueOrNull?.state == AppUpdateCheckState.outdated &&
            update.valueOrNull?.releaseUrl != null) ...[
          SettingsLinkRow(
            label: 'Открыть страницу релиза',
            icon: Icons.open_in_new,
            onTap: () => launchUrl(
              Uri.parse(update.valueOrNull!.releaseUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsSwitchRow(
              label: 'Открывать страницу игры в браузере',
              subtitle: 'Если выключено — нативная страница приложения',
              value: browserMode,
              onChanged: (value) async {
                await ref.read(gamePageBrowserModeProvider.notifier).setEnabled(value);
              },
            ),
            SettingsSwitchRow(
              label: 'UI Inspector (тап-лог + обводка)',
              subtitle:
                  'Пишет в терминал, по чему ты нажал, и подсвечивает элемент рамкой.',
              value: uiInspectorEnabled,
              onChanged: (value) async {
                await ref.read(uiInspectorEnabledProvider.notifier).setEnabled(value);
              },
            ),
            SettingsLinkRow(
              label: 'Скопировать OAuth-токен (${widget.credentialsType})',
              icon: Icons.copy,
              onTap: () => _copyToken(
                context,
                'OAuth-токен (${widget.credentialsType})',
                widget.oauthToken,
              ),
            ),
            SettingsLinkRow(
              label: 'Скопировать полный API key (скачивание и коллекции)',
              icon: Icons.copy,
              onTap: () => _copyFullApiKey(context),
            ),
            SettingsLinkRow(
              label: 'Выйти',
              icon: Icons.logout,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                ref.invalidate(settingsAccountProvider);
                if (context.mounted) {
                  context.go('/gate');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: ItchColors.darkMineShaft,
          backgroundImage: profile.coverUrl != null ? NetworkImage(profile.coverUrl!) : null,
          child: profile.coverUrl == null ? const Icon(Icons.person, size: 22) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: const TextStyle(
                  color: ItchColors.ivory,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '@${profile.username}',
                style: const TextStyle(color: ItchColors.secondaryText, fontSize: 13),
              ),
              Text(
                'ID: ${profile.id}',
                style: const TextStyle(color: ItchColors.zambezi, fontSize: 12),
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
      return const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Полный API key',
          style: TextStyle(color: ItchColors.secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          obscureText: true,
          style: const TextStyle(color: ItchColors.inputText, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ItchColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: ItchColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: ItchColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: ItchColors.borderFocused),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Material(
                color: ItchColors.accent,
                borderRadius: BorderRadius.circular(2),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      'Сохранить',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ItchColors.ivory,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: ItchColors.darkMineShaft,
                borderRadius: BorderRadius.circular(2),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).saveFullApiKey(null);
                    _controller.clear();
                    widget.onSaved();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      'Очистить',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ItchColors.ivory, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
