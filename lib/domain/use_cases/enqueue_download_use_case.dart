import '../../features/downloads/downloads_controller.dart';

class EnqueueDownloadUseCase {
  const EnqueueDownloadUseCase(this._downloadsController);

  final DownloadsController _downloadsController;

  Future<void> call({
    required int gameId,
    required String gameTitle,
  }) {
    return _downloadsController.enqueue(gameId, gameTitle);
  }
}
