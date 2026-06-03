import 'package:flutter/foundation.dart';

/// Логи в стиле itch desktop (`rcall` / `mcall`) для сравнения с butlerd.
void butlerRcall(String message) {
  if (kDebugMode) {
    final ts = DateTime.now().toIso8601String();
    final short = ts.length >= 23 ? ts.substring(11, 23) : ts;
    debugPrint('$short DEBUG (rcall) $message');
  }
}

void butlerMcall(String message) {
  if (kDebugMode) {
    final ts = DateTime.now().toIso8601String();
    final short = ts.length >= 23 ? ts.substring(11, 23) : ts;
    debugPrint('$short DEBUG (mcall) $message');
  }
}
