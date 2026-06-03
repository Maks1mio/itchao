import 'package:flutter/material.dart';

/// CSS-переменные темы страницы игры (`#game_theme` / `.wrapper` на itch.io).
class GamePageTheme {
  const GamePageTheme({
    this.fontFamily,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.innerColumnColor,
    this.textColor,
    this.linkColor,
    this.buttonColor,
    this.buttonForegroundColor,
    this.borderColor,
  });

  final String? fontFamily;
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final Color? innerColumnColor;
  final Color? textColor;
  final Color? linkColor;
  final Color? buttonColor;
  final Color? buttonForegroundColor;
  final Color? borderColor;
}
