import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tourvella_colors.dart';

/// Tema Tourvella.
///
/// Heading memakai Plus Jakarta Sans — buatan perancang Indonesia, dan itu
/// bukan kebetulan. Body memakai Inter karena enak dibaca lama di layar kecil,
/// misalnya saat membaca catatan perjalanan di perjalanan berikutnya.
///
/// Ada dua tema: [build] untuk permukaan terang (daftar, teks panjang) dan
/// [gelap] untuk layar ekspedisi — rekam, peta, cerita, Jejak Nusantara.
/// Dua-duanya memakai palet yang sama; yang berbeda cuma mana yang jadi
/// latar dan mana yang jadi tulisan.
abstract final class TourvellaTheme {
  static ThemeData build() {
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: TourvellaColors.base,
      colorScheme: const ColorScheme.light(
        primary: TourvellaColors.deepAccent,
        onPrimary: TourvellaColors.textOnDeep,
        primaryContainer: TourvellaColors.primary,
        onPrimaryContainer: TourvellaColors.textPrimary,
        secondary: TourvellaColors.softSky,
        onSecondary: TourvellaColors.textPrimary,
        tertiary: TourvellaColors.warmNeutral,
        onTertiary: TourvellaColors.textPrimary,
        surface: TourvellaColors.base,
        onSurface: TourvellaColors.textPrimary,
        error: TourvellaColors.attention,
        onError: TourvellaColors.textOnDeep,
        outline: TourvellaColors.divider,
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: TourvellaColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TourvellaColors.base,
        foregroundColor: TourvellaColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: TourvellaColors.softSky,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      // Tombol utama memakai bara, bukan biru: yang diketuk orang di layar
      // rekam adalah keputusan berangkat, dan itu bukan tindakan sejuk.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TourvellaColors.ember,
          foregroundColor: TourvellaColors.textOnDeep,
          disabledBackgroundColor: TourvellaColors.emberRedup,
          disabledForegroundColor: TourvellaColors.base,
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
          foregroundColor: TourvellaColors.deepAccent,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: TourvellaColors.deepAccent, width: 1.4),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TourvellaColors.deepAccent,
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
          color: TourvellaColors.textSecondary,
        ),
        border: _inputBorder(TourvellaColors.divider),
        enabledBorder: _inputBorder(TourvellaColors.divider),
        focusedBorder: _inputBorder(TourvellaColors.deepAccent, width: 1.6),
        errorBorder: _inputBorder(TourvellaColors.attention),
        focusedErrorBorder: _inputBorder(TourvellaColors.attention, width: 1.6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TourvellaColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: TourvellaColors.textOnDeep,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TourvellaColors.deepAccent,
        linearTrackColor: TourvellaColors.softSky,
        circularTrackColor: TourvellaColors.softSky,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TourvellaColors.deepAccent
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TourvellaColors.primary
              : TourvellaColors.divider,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TourvellaColors.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  /// Sudut sedikit lebih tegas daripada versi pertama (16). Sudut yang
  /// terlalu bulat terbaca lembut dan ramah; yang ini terbaca seperti papan
  /// penunjuk jalan.
  static const _radius = 14.0;

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Tema untuk layar ekspedisi berlatar malam.
  ///
  /// Dipakai dengan membungkus layarnya: `Theme(data: TourvellaTheme.gelap(), …)`.
  /// Tanpa ini, tiap layar gelap harus menyetel warna tiap tombol, kolom
  /// isian, dan pemisahnya sendiri — dan satu yang terlewat langsung terlihat
  /// sebagai kotak putih menyilaukan di tengah malam.
  static ThemeData gelap() {
    final terang = build();
    final teks = _textTheme(diAtasGelap: true);

    return terang.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TourvellaColors.malam,
      colorScheme: const ColorScheme.dark(
        primary: TourvellaColors.ember,
        onPrimary: TourvellaColors.malam,
        primaryContainer: TourvellaColors.malamNaik,
        onPrimaryContainer: TourvellaColors.base,
        secondary: TourvellaColors.primary,
        onSecondary: TourvellaColors.malam,
        tertiary: TourvellaColors.rimba,
        onTertiary: TourvellaColors.base,
        surface: TourvellaColors.malam,
        onSurface: TourvellaColors.base,
        error: TourvellaColors.attention,
        onError: TourvellaColors.malam,
        outline: TourvellaColors.kontur,
      ),
      textTheme: teks,
      appBarTheme: terang.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: TourvellaColors.base,
        titleTextStyle: teks.titleLarge,
      ),
      dividerTheme: const DividerThemeData(
        color: TourvellaColors.kontur,
        thickness: 1,
        space: 1,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TourvellaColors.base,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: TourvellaColors.kontur, width: 1.4),
          textStyle: teks.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TourvellaColors.ember,
          textStyle: teks.labelLarge,
        ),
      ),
      inputDecorationTheme: terang.inputDecorationTheme.copyWith(
        fillColor: TourvellaColors.malamNaik,
        hintStyle: teks.bodyMedium?.copyWith(
          color: TourvellaColors.textSecondary,
        ),
        border: _inputBorder(TourvellaColors.kontur),
        enabledBorder: _inputBorder(TourvellaColors.kontur),
        focusedBorder: _inputBorder(TourvellaColors.ember, width: 1.6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TourvellaColors.ember,
        linearTrackColor: TourvellaColors.malamNaik,
        circularTrackColor: TourvellaColors.malamNaik,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TourvellaColors.malam,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static TextTheme _textTheme({bool diAtasGelap = false}) {
    final heading = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.interTextTheme();

    if (diAtasGelap) {
      // Warna teks dibalik, sisanya persis sama — tipografi Tourvella tidak
      // berubah hanya karena latarnya gelap.
      final terang = _textTheme();
      return terang.apply(
        bodyColor: TourvellaColors.base,
        displayColor: TourvellaColors.base,
      );
    }

    return TextTheme(
      // Judul sengaja lebih berat dan lebih rapat daripada bawaan Material.
      // Versi pertama Tourvella memakai berat sedang di mana-mana, dan hasilnya
      // rapi tapi tanpa suara — tidak ada yang terbaca sebagai "ini
      // perjalananmu", semuanya terbaca sebagai keterangan.
      displaySmall: heading.displaySmall?.copyWith(
        color: TourvellaColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        color: TourvellaColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.18,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        color: TourvellaColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        color: TourvellaColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: heading.titleMedium?.copyWith(
        color: TourvellaColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        color: TourvellaColors.textPrimary,
        height: 1.55,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        color: TourvellaColors.textPrimary,
        height: 1.55,
      ),
      bodySmall: body.bodySmall?.copyWith(
        color: TourvellaColors.textSecondary,
        height: 1.5,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      labelMedium: body.labelMedium?.copyWith(
        color: TourvellaColors.textSecondary,
      ),
    );
  }
}
