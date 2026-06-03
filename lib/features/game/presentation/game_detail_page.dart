import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/itch_colors.dart';
import '../../../data/game_page_fetcher.dart';
import '../../../data/models.dart';
import '../../tabs/presentation/tab_chrome_provider.dart';
import '../../tabs/tabs_controller.dart';
import '../game_catalog.dart';
import '../../../domain/use_cases/launch_game_use_case.dart';
import '../../../domain/use_cases/providers.dart';
import '../../install/game_install_status_provider.dart';
import '../../../data/game_url_resolver.dart';
import '../../../data/game_web_url.dart';
import '../game_detail_provider.dart';
import '../game_url_fix_service.dart';
import 'widgets/itch_game_detail_view.dart';

class GameDetailPage extends ConsumerStatefulWidget {
  const GameDetailPage({required this.gameId, this.fallbackTitle, super.key});

  final int gameId;
  final String? fallbackTitle;

  @override
  ConsumerState<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends ConsumerState<GameDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindChrome());
  }

  @override
  void dispose() {
    final chrome = ref.read(tabChromeProvider.notifier);
    Future.microtask(chrome.clearPageMenu);
    super.dispose();
  }

  void _bindChrome() {
    ref.read(tabChromeProvider.notifier).setPageMenu(
      showTitle: false,
      items: const [
        TabChromeMenuItem(id: 'open_itch', label: 'Открыть на itch.io'),
      ],
      handlers: {
        'open_itch': () => unawaited(_openOnItchFromContext()),
      },
    );
  }

  Future<void> _openOnItchFromContext() async {
    final detail = ref.read(gameDetailProvider(widget.gameId)).valueOrNull;
    final seed = ref.read(gameSeedProvider(widget.gameId));
    final target = detail ?? seed;
    if (target == null) {
      return;
    }
    await _openOnItch(ref, target);
  }

  @override
  Widget build(BuildContext context) {
    final seed = ref.watch(gameSeedProvider(widget.gameId));
    final detailAsync = ref.watch(gameDetailProvider(widget.gameId));
    final ownedAsync = ref.watch(gameOwnedProvider(widget.gameId));
    final uiState = ref.watch(gameInstallUiStateProvider(widget.gameId));
    final tabTitle = _activeTabTitle(ref, widget.gameId);

    return detailAsync.when(
      loading: () {
        if (seed != null) {
          return _body(
            detail: _detailFromSeed(seed),
            displayTitle: seed.title,
            owned: ownedAsync.valueOrNull ?? true,
            uiState: uiState,
            onPrimaryAction: () => _onPrimaryAction(context, ref, seed, uiState),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, _) {
        if (seed != null) {
          return _body(
            detail: _detailFromSeed(seed),
            displayTitle: seed.title,
            owned: ownedAsync.valueOrNull ?? true,
            uiState: uiState,
            onPrimaryAction: () => _onPrimaryAction(context, ref, seed, uiState),
          );
        }
        return _GamePageErrorState(
          gameId: widget.gameId,
          message: error.toString(),
        );
      },
      data: (detail) {
        final displayTitle = _resolveTitle(
          detail: detail,
          seed: seed,
          fallbackTitle: widget.fallbackTitle,
          tabTitle: tabTitle,
        );
        return _body(
          detail: detail,
          displayTitle: displayTitle,
          owned: ownedAsync.valueOrNull ?? seed != null,
          uiState: uiState,
          onPrimaryAction: () => _onPrimaryAction(
            context,
            ref,
            detail,
            uiState,
            displayTitle: displayTitle,
          ),
        );
      },
    );
  }

  Widget _body({
    required GameDetail detail,
    required String displayTitle,
    required bool owned,
    required GameInstallUiState uiState,
    required VoidCallback onPrimaryAction,
  }) {
    return ItchGameDetailView(
      detail: detail,
      displayTitle: displayTitle,
      owned: owned,
      uiState: uiState,
      onPrimaryAction: onPrimaryAction,
    );
  }

  static String _resolveTitle({
    required GameDetail detail,
    required LibraryGame? seed,
    required String? fallbackTitle,
    required String? tabTitle,
  }) {
    for (final candidate in [detail.title, seed?.title, fallbackTitle, tabTitle]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty && trimmed != 'Игра') {
        return trimmed;
      }
    }
    return 'Игра';
  }

  static String? _activeTabTitle(WidgetRef ref, int gameId) {
    final tabs = ref.watch(tabsControllerProvider).valueOrNull;
    final active = tabs?.activeTab;
    if (active == null) {
      return null;
    }
    if (active.url.contains('games/$gameId')) {
      return active.label;
    }
    return null;
  }

  static GameDetail _detailFromSeed(LibraryGame seed) {
    return GameDetail(
      id: seed.id,
      title: seed.title,
      webUrl: gameWebUrl(seed) ?? 'https://itch.io',
      iconUrl: seed.coverUrl,
      coverUrl: seed.coverUrl,
      heroImageUrl: seed.coverUrl,
      shortText: seed.shortText ?? '',
      classification: seed.classification,
      platforms: seed.platforms,
    );
  }

  Future<void> _openOnItch(WidgetRef ref, Object target) async {
    final label = switch (target) {
      GameDetail d => d.title,
      LibraryGame g => g.title,
      _ => 'Игра',
    };

    var url = switch (target) {
      GameDetail d => d.webUrl,
      LibraryGame g => gameWebUrl(g),
      _ => null,
    };

    if (!GameWebUrl.isValid(url) && target is LibraryGame) {
      try {
        url = await ref.read(gameUrlResolverProvider).resolve(
          gameId: target.id,
          seed: target,
        );
      } catch (_) {
        url = null;
      }
    }

    ref.read(tabsControllerProvider.notifier).navigateActiveTab(
      url ?? 'https://itch.io',
      label: label,
    );
  }

  Future<void> _onPrimaryAction(
    BuildContext context,
    WidgetRef ref,
    Object target,
    GameInstallUiState uiState, {
    String? displayTitle,
  }) async {
    final id = switch (target) {
      GameDetail d => d.id,
      LibraryGame g => g.id,
      _ => 0,
    };
    final title = displayTitle ??
        switch (target) {
          GameDetail d => d.title,
          LibraryGame g => g.title,
          _ => 'Игра',
        };
    final cover = switch (target) {
      GameDetail d => d.coverUrl ?? d.iconUrl,
      LibraryGame g => g.coverUrl,
      _ => null,
    };
    if (id <= 0) {
      return;
    }

    if (uiState.action == GamePrimaryAction.play) {
      try {
        await ref.read(launchGameUseCaseProvider).call(
          gameId: id,
          title: title,
          coverUrl: cover,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось запустить: $e')),
          );
        }
      }
      return;
    }

    if (uiState.action == GamePrimaryAction.install ||
        uiState.action == GamePrimaryAction.update) {
      final reason = uiState.action == GamePrimaryAction.update
          ? DownloadReason.update
          : DownloadReason.install;
      await ref.read(enqueueDownloadUseCaseProvider).call(
        gameId: id,
        gameTitle: title,
        reason: reason,
        coverUrl: cover,
      );
      if (context.mounted) {
        context.push('/downloads');
      }
    }
  }
}

class _GamePageErrorState extends ConsumerStatefulWidget {
  const _GamePageErrorState({required this.gameId, required this.message});

  final int gameId;
  final String message;

  @override
  ConsumerState<_GamePageErrorState> createState() => _GamePageErrorStateState();
}

class _GamePageErrorStateState extends ConsumerState<_GamePageErrorState> {
  bool _busy = false;

  Future<void> _runAutoFix() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(gameUrlFixServiceProvider).tryAutoFix(widget.gameId);
      if (!mounted) {
        return;
      }
      if (result != null) {
        ref.invalidate(gameDetailProvider(widget.gameId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка исправлена')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Авто-поиск не нашёл страницу. Вставьте ссылку с itch.io вручную.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pasteUrl() async {
    final controller = TextEditingController();
    final title = ref.read(gameUrlFixServiceProvider).titleHintFor(widget.gameId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ItchColors.item,
        title: const Text('Ссылка на игру', style: TextStyle(color: ItchColors.ivory)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Вставьте адрес со страницы itch.io (например author.itch.io/game).',
              style: TextStyle(color: ItchColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: ItchColors.ivory),
              decoration: InputDecoration(
                hintText: title != null ? 'https://….itch.io/…' : null,
                hintStyle: TextStyle(color: ItchColors.zambezi.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(gameUrlFixServiceProvider).applyManualUrl(
        widget.gameId,
        controller.text,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(gameDetailProvider(widget.gameId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка сохранена')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openSearch() {
    final fix = ref.read(gameUrlFixServiceProvider);
    final title = fix.titleHintFor(widget.gameId) ?? 'game';
    ref.read(tabsControllerProvider.notifier).navigateActiveTab(
      fix.searchUrlForTitle(title),
      label: 'Поиск: $title',
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final title = ref.read(gameUrlFixServiceProvider).titleHintFor(widget.gameId);

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Не удалось загрузить страницу игры.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ItchColors.ivory,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ItchColors.secondaryText, fontSize: 15),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ItchColors.secondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              if (_busy)
                const CircularProgressIndicator(color: ItchColors.accent)
              else ...[
                FilledButton.icon(
                  onPressed: _runAutoFix,
                  icon: const Icon(Icons.build_outlined, size: 20),
                  label: const Text('Исправить ссылку'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pasteUrl,
                  icon: const Icon(Icons.link, size: 20),
                  label: const Text('Вставить ссылку'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _openSearch,
                  child: const Text('Найти на itch.io'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
