import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/downloads/downloads_controller.dart';
import '../../features/library/library_controller.dart';
import 'auth_login_use_case.dart';
import 'enqueue_download_use_case.dart';
import 'fetch_library_use_case.dart';

final authLoginUseCaseProvider = Provider<AuthLoginUseCase>((ref) {
  return AuthLoginUseCase(ref.read(authControllerProvider.notifier));
});

final fetchLibraryUseCaseProvider = Provider<FetchLibraryUseCase>((ref) {
  return FetchLibraryUseCase(ref.read(libraryControllerProvider.notifier));
});

final enqueueDownloadUseCaseProvider = Provider<EnqueueDownloadUseCase>((ref) {
  return EnqueueDownloadUseCase(ref.read(downloadsControllerProvider.notifier));
});
