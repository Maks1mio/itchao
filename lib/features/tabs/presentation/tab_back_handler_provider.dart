import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Обработчик системной «Назад» для активной вкладки (WebView и т.п.).
/// Возвращает `true`, если событие обработано.
final tabBackHandlerProvider = StateProvider<Future<bool> Function()?>((ref) => null);
