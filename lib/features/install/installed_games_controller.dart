import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/android/apk_platform_channel.dart';
import '../../data/install_models.dart';
import '../../data/repositories/installed_games_repository.dart';
import 'installed_games_discovery.dart';

final installedGamesRepositoryProvider = Provider<InstalledGamesRepository>((ref) {
  return InstalledGamesRepository();
});

final installedGamesProvider =
    NotifierProvider<InstalledGamesController, Map<int, InstalledGameRecord>>(
      InstalledGamesController.new,
    );

class InstalledGamesController extends Notifier<Map<int, InstalledGameRecord>> {
  @override
  Map<int, InstalledGameRecord> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final loaded = await ref.read(installedGamesRepositoryProvider).loadAll();
    state = loaded;
    await discoverFromDevice();
    state = await _pruneMissingOnDevice(state);
  }

  Future<void> refresh() => _load();

  /// Находит на телефоне приложения, установленные через itchao, и добавляет в реестр.
  Future<void> discoverFromDevice() async {
    await ref.read(installedGamesDiscoveryProvider).syncFromDevice();
  }

  /// Синхронизация с устройством: обнаружение новых + удаление снятых.
  Future<void> syncWithDevice() async {
    if (state.isEmpty) {
      final loaded = await ref.read(installedGamesRepositoryProvider).loadAll();
      state = loaded;
    }
    await discoverFromDevice();
    state = await _pruneMissingOnDevice(state);
  }

  Future<Map<int, InstalledGameRecord>> _pruneMissingOnDevice(
    Map<int, InstalledGameRecord> games,
  ) async {
    if (games.isEmpty) {
      return games;
    }
    final apk = ref.read(apkPlatformChannelProvider);
    final repo = ref.read(installedGamesRepositoryProvider);
    final next = Map<int, InstalledGameRecord>.from(games);
    for (final entry in games.entries) {
      final pkg = entry.value.packageName;
      if (pkg.isEmpty || !await apk.isAppInstalled(pkg)) {
        next.remove(entry.key);
        await repo.remove(entry.key);
      }
    }
    return next;
  }

  Future<void> upsert(InstalledGameRecord record) async {
    await ref.read(installedGamesRepositoryProvider).upsert(record);
    state = {...state, record.gameId: record};
  }

  Future<void> remove(int gameId) async {
    await ref.read(installedGamesRepositoryProvider).remove(gameId);
    final next = Map<int, InstalledGameRecord>.from(state)..remove(gameId);
    state = next;
  }

  InstalledGameRecord? get(int gameId) => state[gameId];
}
