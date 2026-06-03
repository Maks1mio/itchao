import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories/download_history_repository.dart';
import 'download_history_entry.dart';

final downloadHistoryRepositoryProvider = Provider<DownloadHistoryRepository>((ref) {
  return DownloadHistoryRepository();
});

final downloadHistoryProvider =
    AsyncNotifierProvider<DownloadHistoryController, List<DownloadHistoryEntry>>(
      DownloadHistoryController.new,
    );

class DownloadHistoryController extends AsyncNotifier<List<DownloadHistoryEntry>> {
  @override
  Future<List<DownloadHistoryEntry>> build() async {
    return ref.read(downloadHistoryRepositoryProvider).loadAll();
  }

  Future<void> recordFromTask(DownloadTask task, DownloadStatus status) async {
    final entry = DownloadHistoryEntry.fromTask(task, status: status);
    await ref.read(downloadHistoryRepositoryProvider).upsert(entry);
    final current = state.value ??
        await ref.read(downloadHistoryRepositoryProvider).loadAll();
    state = AsyncData([
      entry,
      ...current.where((e) => e.gameId != entry.gameId && e.id != entry.id),
    ]);
  }

  Future<void> remove(String id) async {
    await ref.read(downloadHistoryRepositoryProvider).remove(id);
    final current = state.value ?? const [];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }

  Future<void> clearAll() async {
    await ref.read(downloadHistoryRepositoryProvider).clear();
    state = const AsyncData([]);
  }

  List<DownloadHistoryEntry> completedEntries() {
    return (state.value ?? const [])
        .where((e) => e.status == DownloadStatus.completed)
        .toList();
  }
}
