import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uiInspectorPrefKey = 'debug.ui_inspector.enabled';

final uiInspectorEnabledProvider =
    StateNotifierProvider<UiInspectorEnabledNotifier, bool>(
      (ref) => UiInspectorEnabledNotifier(),
    );

class UiInspectorEnabledNotifier extends StateNotifier<bool> {
  UiInspectorEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_uiInspectorPrefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_uiInspectorPrefKey, enabled);
  }
}
