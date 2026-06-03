import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drawer открыт — тело вкладки приостанавливает анимации (меньше лагов).
final hubDrawerOpenProvider = StateProvider<bool>((ref) => false);
