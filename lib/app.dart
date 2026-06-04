import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug/ui_inspector_overlay.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models.dart';
import 'features/downloads/downloads_controller.dart';
import 'features/install/installed_games_controller.dart';
import 'features/library/library_controller.dart';
import 'features/settings/ui_inspector_settings_provider.dart';

class ItchaoApp extends ConsumerStatefulWidget {
  const ItchaoApp({super.key});

  @override
  ConsumerState<ItchaoApp> createState() => _ItchaoAppState();
}

class _ItchaoAppState extends ConsumerState<ItchaoApp> with WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      final hasInstallInProgress = ref.read(downloadsControllerProvider).any(
        (t) => t.status == DownloadStatus.installing,
      );
      if (hasInstallInProgress) {
        unawaited(ref.read(downloadsControllerProvider.notifier).reconcileActiveTasks());
      }
    }
    if (_shouldRefreshOnResume(state)) {
      _onAppResumed();
    }
    _lastLifecycleState = state;
  }

  bool _shouldRefreshOnResume(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return false;
    }
    // Шторка уведомлений / системные оверлеи часто дают inactive->resumed.
    // Не делаем тяжёлый refresh в этом случае, чтобы не "перезагружать" экран.
    if (_lastLifecycleState != AppLifecycleState.paused) {
      return false;
    }
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      return false;
    }
    final pausedFor = DateTime.now().difference(pausedAt);
    // Короткая пауза (несколько секунд) чаще всего системный жест/шторка.
    return pausedFor >= const Duration(seconds: 8);
  }

  Future<void> _onAppResumed() async {
    await ref.read(libraryControllerProvider.notifier).refresh();
    await ref.read(installedGamesProvider.notifier).syncWithDevice();
    await ref.read(downloadsControllerProvider.notifier).reconcileActiveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final inspectorEnabled = ref.watch(uiInspectorEnabledProvider);
    return MaterialApp.router(
      title: 'itchao',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return UiInspectorOverlay(
          enabled: inspectorEnabled,
          child: child,
        );
      },
    );
  }
}
