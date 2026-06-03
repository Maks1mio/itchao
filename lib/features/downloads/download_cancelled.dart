/// Thrown when the user cancels an in-flight download/install task.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

typedef DownloadCancelledCheck = bool Function();
