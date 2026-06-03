import '../../data/models.dart';

class AppState {
  const AppState({
    this.profile,
    this.library = const [],
    this.downloads = const [],
  });

  final UserProfile? profile;
  final List<LibraryGame> library;
  final List<DownloadTask> downloads;

  AppState copyWith({
    UserProfile? profile,
    List<LibraryGame>? library,
    List<DownloadTask>? downloads,
  }) {
    return AppState(
      profile: profile ?? this.profile,
      library: library ?? this.library,
      downloads: downloads ?? this.downloads,
    );
  }
}
