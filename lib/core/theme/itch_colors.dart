import 'package:flutter/material.dart';

/// Палитра itch desktop (`itch-master/src/renderer/styles.ts`).
abstract final class ItchColors {
  static const accent = Color(0xFFFA5C5C);
  static const accentLight = Color(0xFFFF8080);

  static const background = Color(0xFF1D1D1D);
  static const bread = Color(0xFF141414);
  static const item = Color(0xFF1E1E1E);
  static const codGray = Color(0xFF151515);

  static const darkMineShaft = Color(0xFF2E2B2C);
  static const lightMineShaft = Color(0xFF383434);
  static const zambezi = Color(0xFF5D5757);

  static const ivory = Color(0xFFFFFFF0);
  static const inputText = Color(0xFFD4CECE);
  static const silverChalice = Color(0xFFA0A0A0);
  static const secondaryText = Color(0xFFB0B0B0);

  static const border = Color(0xFF404040);
  static const borderFocused = Color(0xFF676767);

  static const error = Color(0xFFD14343);
  static const success = Color(0xFFB9E8A1);
  static const warning = Color(0xFFEFEEBF);

  /// `item` @ 85% opacity (loading stripe overlay).
  static const itemLoadingOverlay = Color(0xD91E1E1E);
  static const caution = Color(0xFFDCA03C);

  static const filterBackground = Color(0xFF4A4848);
  static const filterTagBackground = Color(0xFF5F5C5C);
  static const filterTagText = Color(0xFFE0DFDF);

  static const divider = Color(0xFF333333);
}
