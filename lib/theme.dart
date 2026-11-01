import 'package:flutter/material.dart';

/// Instagram-at-night: true black, white type, Doomy's lavender, one blue for "verified" and your messages.
class Palette {
  static const ink = Color(0xFF000000);
  static const card = Color(0xFF121212);
  static const bubble = Color(0xFF262626);
  static const line = Color(0xFF262626);
  static const white = Color(0xFFF5F5F5);
  static const muted = Color(0xFFA8A8A8);
  static const doomy = Color(0xFFA99BFF);
  static const blue = Color(0xFF3797F0);
  static const danger = Color(0xFFFF5C5C);
  static const live = Color(0xFF58C322);
  static const adYellow = Color(0xFFFFD44D);
}

class Txt {
  static const wordmark = TextStyle(
      fontFamily: 'Anton', fontSize: 30, letterSpacing: 0.5, color: Palette.white, height: 1.1);
  static const meme =
      TextStyle(fontFamily: 'Anton', fontSize: 30, height: 1.05, color: Colors.white);
  static const bigNumber =
      TextStyle(fontFamily: 'Anton', fontSize: 56, height: 1.0, color: Palette.white);
  static const heading = TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 1.2,
      color: Palette.white);
  static const title = TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w600,
      fontSize: 17,
      height: 1.3,
      color: Palette.white);
  static const body = TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.4,
      color: Palette.white);
  static const quiet = TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w400,
      fontSize: 15,
      height: 1.4,
      color: Palette.muted);
  static const small = TextStyle(
      fontFamily: 'Figtree',
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 1.35,
      color: Palette.muted);
  static const label =
      TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w600, fontSize: 15, height: 1.2);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.doomy,
    onPrimary: Palette.ink,
    secondary: Palette.blue,
    onSecondary: Colors.white,
    surface: Palette.ink,
    onSurface: Palette.white,
    surfaceContainerHighest: Palette.card,
    outline: Palette.line,
    outlineVariant: Palette.line,
    error: Palette.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.ink,
    canvasColor: Palette.ink,
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
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.ink,
      foregroundColor: Palette.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: Txt.title,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.ink : Palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.doomy : Palette.ink,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.doomy : Palette.line,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.doomy,
        foregroundColor: Palette.ink,
        textStyle: Txt.label,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.white,
        textStyle: Txt.label,
        side: const BorderSide(color: Palette.line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.blue, textStyle: Txt.label),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.bubble,
      contentTextStyle: Txt.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.card,
      showDragHandle: true,
      dragHandleColor: Palette.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.card,
      titleTextStyle: Txt.title,
      contentTextStyle: Txt.quiet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
