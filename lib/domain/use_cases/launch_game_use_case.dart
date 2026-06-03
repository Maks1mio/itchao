import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/butler/butler_adapter.dart';
import '../../features/play_history/play_history_controller.dart';

final launchGameUseCaseProvider = Provider<LaunchGameUseCase>((ref) {
  return LaunchGameUseCase(ref);
});

/// Запуск игры + запись «последний раз в игре» (как itch desktop / butler).
class LaunchGameUseCase {
  LaunchGameUseCase(this._ref);

  final Ref _ref;

  Future<void> call({
    required int gameId,
    required String title,
    String? coverUrl,
  }) async {
    await _ref.read(playHistoryProvider.notifier).recordPlay(
      gameId: gameId,
      title: title,
      coverUrl: coverUrl,
    );
    await _ref.read(butlerAdapterProvider).launchGame(
      gameId: gameId,
      gameTitle: title,
      coverUrl: coverUrl,
    );
  }
}
