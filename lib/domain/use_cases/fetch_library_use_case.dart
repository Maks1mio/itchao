import '../../data/models.dart';
import '../../features/library/library_controller.dart';

class FetchLibraryUseCase {
  const FetchLibraryUseCase(this._libraryController);

  final LibraryController _libraryController;

  Future<List<LibraryGame>> call() async {
    await _libraryController.refresh();
    return _libraryController.currentValue();
  }
}
