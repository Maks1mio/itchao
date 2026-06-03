import '../../data/models.dart';

String formatBytesPerSecond(double? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond <= 0) {
    return '—';
  }
  final bps = bytesPerSecond;
  if (bps >= 1024 * 1024) {
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MiB/s';
  }
  if (bps >= 1024) {
    return '${(bps / 1024).toStringAsFixed(1)} KiB/s';
  }
  return '${bps.round()} B/s';
}

String formatEtaRu(int? seconds) {
  if (seconds == null || seconds <= 0) {
    return '';
  }
  if (seconds < 60) {
    return '$seconds сек.';
  }
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) {
    return '$minutes мин.';
  }
  final hours = minutes ~/ 60;
  final remMin = minutes % 60;
  if (remMin == 0) {
    return '$hours ч.';
  }
  return '$hours ч. $remMin мин.';
}

String formatDownloadSpeedLine({double? bytesPerSecond, int? etaSeconds}) {
  final speed = formatBytesPerSecond(bytesPerSecond);
  final eta = formatEtaRu(etaSeconds);
  if (eta.isEmpty) {
    return speed;
  }
  return '$speed — $eta';
}

String downloadReasonLabelRu(DownloadReason reason) {
  return switch (reason) {
    DownloadReason.install => 'установка',
    DownloadReason.update => 'обновление',
    DownloadReason.reinstall => 'переустановка',
  };
}
