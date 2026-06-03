import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/android/install_event_channel.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/downloads/downloads_controller.dart';
import 'features/install/installed_games_controller.dart';
import 'features/library/library_controller.dart';

class ItchaoApp extends ConsumerStatefulWidget {
  const ItchaoApp({super.key});

  @override
  ConsumerState<ItchaoApp> createState() => _ItchaoAppState();
}

class _ItchaoAppState extends ConsumerState<ItchaoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InstallEventChannel.bind(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    await ref.read(libraryControllerProvider.notifier).refresh();
    await ref.read(installedGamesProvider.notifier).syncWithDevice();
    await ref.read(downloadsControllerProvider.notifier).reconcileActiveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'itchao',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
