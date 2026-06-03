import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories/library_repository.dart';
import '../auth/auth_controller.dart';

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<LibraryGame>>(
      LibraryController.new,
    );

class LibraryController extends AsyncNotifier<List<LibraryGame>> {
  @override
  Future<List<LibraryGame>> build() async {
    final apiKey = await ref.read(authControllerProvider.notifier).readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const [];
    }
    final repository = LibraryRepository(ref.read(itchApiClientProvider));
    return repository.fetchLibrary(apiKey);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  List<LibraryGame> currentValue() {
    return state.value ?? const [];
  }
}
