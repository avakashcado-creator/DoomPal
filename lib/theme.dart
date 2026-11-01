import 'package:flutter/material.dart';

/// "Greenhouse at night": deep moss, pale lichen text, one pollen accent.
class Palette {
  static const moss = Color(0xFF15221D); // background
  static const bark = Color(0xFF1D2E27); // raised surfaces (sheets, notes)
  static const vein = Color(0xFF2D4339); // hairlines, empty ticks
  static const lichen = Color(0xFFE3EADB); // main text
  static const sage = Color(0xFF93A799); // quiet text
  static const pollen = Color(0xFFE9C46A); // the accent
  static const petal = Color(0xFFF2C4D0); // flowers, streaks
  static const straw = Color(0xFFC9A45C); // over the limit
}

/// Type scale. Fraunces carries numbers and headings, Figtree does the reading.
class Txt {
  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: 'FrauncesDisplay',
    fontWeight: FontWeight.w400,
    fontSize: 104,
    height: 1.0,
    letterSpacing: -3,
    color: Palette.lichen,
    fontFeatures: _tabular,
  );
  static const heading = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w400,
    fontSize: 30,
    height: 1.15,
    letterSpacing: -0.4,
    color: Palette.lichen,
  );
  static const title = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    height: 1.3,
    color: Palette.lichen,
  );
  static const number = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    height: 1.2,
    color: Palette.lichen,
    fontFeatures: _tabular,
  );
  static const body = TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.45,
    color: Palette.lichen,
  );
  static const quiet = TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
    color: Palette.sage,
  );
  static const small = TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: Palette.sage,
  );
  static const label = TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.pollen,
    onPrimary: Palette.moss,
    secondary: Palette.petal,
    onSecondary: Palette.moss,
    surface: Palette.moss,
    onSurface: Palette.lichen,
    surfaceContainerHighest: Palette.bark,
    outline: Palette.vein,
    outlineVariant: Palette.vein,
    error: Color(0xFFE8907E),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.moss,
    canvasColor: Palette.moss,
    fontFamily: 'Figtree',
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      bodyLarge: Txt.body,
      bodyMedium: Txt.body,
      bodySmall: Txt.small,
      titleMedium: Txt.body,
      titleLarge: Txt.title,
      headlineSmall: Txt.heading,
    ),
    dividerTheme:
        const DividerThemeData(color: Palette.vein, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.moss,
      foregroundColor: Palette.lichen,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: Txt.title,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.moss : Palette.sage,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.pollen : Palette.moss,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.pollen : Palette.vein,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.pollen,
        foregroundColor: Palette.moss,
        textStyle: Txt.label,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.lichen,
        textStyle: Txt.label,
        side: const BorderSide(color: Palette.vein),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: Palette.pollen, textStyle: Txt.label),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.bark,
      contentTextStyle: Txt.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.bark,
      showDragHandle: true,
      dragHandleColor: Palette.vein,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.bark,
      titleTextStyle: Txt.title,
      contentTextStyle: Txt.quiet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
