import 'package:flutter/material.dart';

import 'itch_colors.dart';

/// Тема как в itch desktop (`itch-master/src/renderer/styles.ts`).
final class AppTheme {
  static ThemeData get dark => _buildDark();

  static ThemeData get light => dark;

  static ThemeData _buildDark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ItchColors.accent,
      onPrimary: ItchColors.ivory,
      primaryContainer: ItchColors.darkMineShaft,
      onPrimaryContainer: ItchColors.ivory,
      secondary: ItchColors.filterTagBackground,
      onSecondary: ItchColors.filterTagText,
      secondaryContainer: ItchColors.filterBackground,
      onSecondaryContainer: ItchColors.filterTagText,
      tertiary: ItchColors.zambezi,
      onTertiary: ItchColors.ivory,
      error: ItchColors.error,
      onError: ItchColors.ivory,
      errorContainer: Color(0xFF3D2020),
      onErrorContainer: ItchColors.accentLight,
      surface: ItchColors.bread,
      onSurface: ItchColors.ivory,
      onSurfaceVariant: ItchColors.secondaryText,
      outline: ItchColors.border,
      outlineVariant: ItchColors.zambezi,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: ItchColors.ivory,
      onInverseSurface: ItchColors.codGray,
      inversePrimary: ItchColors.accentLight,
      surfaceTint: ItchColors.accent,
      surfaceContainerLowest: ItchColors.codGray,
      surfaceContainerLow: ItchColors.bread,
      surfaceContainer: ItchColors.item,
      surfaceContainerHigh: ItchColors.darkMineShaft,
      surfaceContainerHighest: ItchColors.lightMineShaft,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ItchColors.background,
      dividerColor: ItchColors.divider,
      splashColor: ItchColors.accent.withValues(alpha: 0.12),
      highlightColor: ItchColors.accent.withValues(alpha: 0.08),
      fontFamily: _fontFamily,
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: ItchColors.bread,
        foregroundColor: ItchColors.ivory,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ItchColors.ivory,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ItchColors.secondaryText),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: ItchColors.bread,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: ItchColors.item,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ItchColors.secondaryText,
        textColor: ItchColors.ivory,
        selectedTileColor: Color(0x14FFFFFF),
        selectedColor: ItchColors.ivory,
      ),
      iconTheme: const IconThemeData(color: ItchColors.secondaryText),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ItchColors.accent,
        linearTrackColor: Color(0x78A5A5A5),
      ),
      dividerTheme: const DividerThemeData(color: ItchColors.divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ItchColors.background,
        hintStyle: const TextStyle(color: ItchColors.silverChalice),
        labelStyle: const TextStyle(color: ItchColors.secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ItchColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ItchColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ItchColors.borderFocused, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ItchColors.filterTagBackground,
        deleteIconColor: ItchColors.filterTagText,
        disabledColor: ItchColors.filterBackground,
        selectedColor: ItchColors.accent.withValues(alpha: 0.35),
        secondarySelectedColor: ItchColors.filterBackground,
        labelStyle: const TextStyle(color: ItchColors.filterTagText, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: ItchColors.filterTagText, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: ItchColors.filterTagBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ItchColors.accent,
          foregroundColor: ItchColors.ivory,
          disabledBackgroundColor: ItchColors.zambezi,
          disabledForegroundColor: ItchColors.silverChalice,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ItchColors.secondaryText,
          side: const BorderSide(color: ItchColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ItchColors.accentLight,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ItchColors.lightMineShaft,
        contentTextStyle: TextStyle(color: ItchColors.ivory),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ItchColors.item,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(color: ItchColors.ivory, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: ItchColors.inputText, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: ItchColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ItchColors.bread,
        indicatorColor: ItchColors.accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: selected ? ItchColors.ivory : ItchColors.zambezi,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? ItchColors.accent : ItchColors.zambezi);
        }),
      ),
    );

    return base;
  }

  static const _fontFamily = 'Lato';

  static final _textTheme = _baseTextTheme.apply(fontFamily: _fontFamily);

  static const _baseTextTheme = TextTheme(
    displayLarge: TextStyle(color: ItchColors.ivory, fontSize: 30, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: ItchColors.ivory, fontSize: 23, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: ItchColors.ivory, fontSize: 19, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(color: ItchColors.ivory, fontSize: 18, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: ItchColors.ivory, fontSize: 16, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: ItchColors.ivory, fontSize: 16, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: ItchColors.ivory, fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: ItchColors.ivory, fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(color: ItchColors.ivory, fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: ItchColors.inputText, fontSize: 15),
    bodyMedium: TextStyle(color: ItchColors.inputText, fontSize: 15),
    bodySmall: TextStyle(color: ItchColors.secondaryText, fontSize: 13),
    labelLarge: TextStyle(color: ItchColors.ivory, fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(color: ItchColors.secondaryText, fontSize: 12),
    labelSmall: TextStyle(color: ItchColors.zambezi, fontSize: 12),
  );
}
