String formatTimeAgoRu(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) {
    final years = diff.inDays ~/ 365;
    return '$years г. назад';
  }
  if (diff.inDays >= 30) {
    final months = diff.inDays ~/ 30;
    return '$months мес. назад';
  }
  if (diff.inDays >= 7) {
    final weeks = diff.inDays ~/ 7;
    return '$weeks нед. назад';
  }
  if (diff.inDays >= 1) {
    return '${diff.inDays} дн. назад';
  }
  if (diff.inHours >= 1) {
    return '${diff.inHours} ч. назад';
  }
  return 'только что';
}

String formatProjectsCountRu(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return '$count проектов';
  }
  if (mod10 == 1) {
    return '$count проект';
  }
  if (mod10 >= 2 && mod10 <= 4) {
    return '$count проекта';
  }
  return '$count проектов';
}
