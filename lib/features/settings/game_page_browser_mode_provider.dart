import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'preferences.game_page_browser_mode';

final gamePageBrowserModeProvider =
    StateNotifierProvider<GamePageBrowserModeNotifier, bool>(
      (ref) => GamePageBrowserModeNotifier(),
    );

class GamePageBrowserModeNotifier extends StateNotifier<bool> {
  GamePageBrowserModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
