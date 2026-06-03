class DownloadProgressUpdate {
  const DownloadProgressUpdate({
    required this.progress,
    this.bytesPerSecond,
    this.etaSeconds,
    this.filename,
    this.packageName,
  });

  final double progress;
  final double? bytesPerSecond;
  final int? etaSeconds;
  final String? filename;
  final String? packageName;
}
