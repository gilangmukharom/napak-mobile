import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'napak_colors.dart';

/// Tema Napak.
///
/// Heading memakai Plus Jakarta Sans — buatan perancang Indonesia, dan itu
/// bukan kebetulan. Body memakai Inter karena enak dibaca lama di layar kecil,
/// misalnya saat membaca catatan perjalanan di perjalanan berikutnya.
abstract final class NapakTheme {
  static ThemeData build() {
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: NapakColors.base,
      colorScheme: const ColorScheme.light(
        primary: NapakColors.deepAccent,
        onPrimary: NapakColors.textOnDeep,
        primaryContainer: NapakColors.primary,
        onPrimaryContainer: NapakColors.textPrimary,
        secondary: NapakColors.softSky,
        onSecondary: NapakColors.textPrimary,
        tertiary: NapakColors.warmNeutral,
        onTertiary: NapakColors.textPrimary,
        surface: NapakColors.base,
        onSurface: NapakColors.textPrimary,
        error: NapakColors.attention,
        onError: NapakColors.textOnDeep,
        outline: NapakColors.divider,
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: NapakColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NapakColors.base,
        foregroundColor: NapakColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: NapakColors.softSky,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NapakColors.deepAccent,
          foregroundColor: NapakColors.textOnDeep,
          disabledBackgroundColor: NapakColors.primary,
          disabledForegroundColor: NapakColors.textOnDeep,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NapakColors.deepAccent,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: NapakColors.primary, width: 1.5),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NapakColors.deepAccent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: NapakColors.textSecondary,
        ),
        border: _inputBorder(NapakColors.divider),
        enabledBorder: _inputBorder(NapakColors.divider),
        focusedBorder: _inputBorder(NapakColors.deepAccent, width: 1.6),
        errorBorder: _inputBorder(NapakColors.attention),
        focusedErrorBorder: _inputBorder(NapakColors.attention, width: 1.6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NapakColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: NapakColors.textOnDeep,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NapakColors.deepAccent,
        linearTrackColor: NapakColors.softSky,
        circularTrackColor: NapakColors.softSky,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NapakColors.deepAccent
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NapakColors.primary
              : NapakColors.divider,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NapakColors.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static const _radius = 16.0;

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme() {
    final heading = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      displaySmall: heading.displaySmall?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: heading.titleMedium?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        color: NapakColors.textPrimary,
        height: 1.55,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        color: NapakColors.textPrimary,
        height: 1.55,
      ),
      bodySmall: body.bodySmall?.copyWith(
        color: NapakColors.textSecondary,
        height: 1.5,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: body.labelMedium?.copyWith(
        color: NapakColors.textSecondary,
      ),
    );
  }
}
