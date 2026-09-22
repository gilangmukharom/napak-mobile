import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'napak_colors.dart';

/// Tema Napak.
///
/// Heading memakai Plus Jakarta Sans — buatan perancang Indonesia, dan itu
/// bukan kebetulan. Body memakai Inter karena enak dibaca lama di layar kecil,
/// misalnya saat membaca catatan perjalanan di perjalanan berikutnya.
///
/// Ada dua tema: [build] untuk permukaan terang (daftar, teks panjang) dan
/// [gelap] untuk layar ekspedisi — rekam, peta, cerita, Jejak Nusantara.
/// Dua-duanya memakai palet yang sama; yang berbeda cuma mana yang jadi
/// latar dan mana yang jadi tulisan.
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
      // Tombol utama memakai bara, bukan biru: yang diketuk orang di layar
      // rekam adalah keputusan berangkat, dan itu bukan tindakan sejuk.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NapakColors.ember,
          foregroundColor: NapakColors.textOnDeep,
          disabledBackgroundColor: NapakColors.emberRedup,
          disabledForegroundColor: NapakColors.base,
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
          side: const BorderSide(color: NapakColors.deepAccent, width: 1.4),
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
  /// Dipakai dengan membungkus layarnya: `Theme(data: NapakTheme.gelap(), …)`.
  /// Tanpa ini, tiap layar gelap harus menyetel warna tiap tombol, kolom
  /// isian, dan pemisahnya sendiri — dan satu yang terlewat langsung terlihat
  /// sebagai kotak putih menyilaukan di tengah malam.
  static ThemeData gelap() {
    final terang = build();
    final teks = _textTheme(diAtasGelap: true);

    return terang.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NapakColors.malam,
      colorScheme: const ColorScheme.dark(
        primary: NapakColors.ember,
        onPrimary: NapakColors.malam,
        primaryContainer: NapakColors.malamNaik,
        onPrimaryContainer: NapakColors.base,
        secondary: NapakColors.primary,
        onSecondary: NapakColors.malam,
        tertiary: NapakColors.rimba,
        onTertiary: NapakColors.base,
        surface: NapakColors.malam,
        onSurface: NapakColors.base,
        error: NapakColors.attention,
        onError: NapakColors.malam,
        outline: NapakColors.kontur,
      ),
      textTheme: teks,
      appBarTheme: terang.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: NapakColors.base,
        titleTextStyle: teks.titleLarge,
      ),
      dividerTheme: const DividerThemeData(
        color: NapakColors.kontur,
        thickness: 1,
        space: 1,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NapakColors.base,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: NapakColors.kontur, width: 1.4),
          textStyle: teks.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NapakColors.ember,
          textStyle: teks.labelLarge,
        ),
      ),
      inputDecorationTheme: terang.inputDecorationTheme.copyWith(
        fillColor: NapakColors.malamNaik,
        hintStyle: teks.bodyMedium?.copyWith(color: NapakColors.textSecondary),
        border: _inputBorder(NapakColors.kontur),
        enabledBorder: _inputBorder(NapakColors.kontur),
        focusedBorder: _inputBorder(NapakColors.ember, width: 1.6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NapakColors.ember,
        linearTrackColor: NapakColors.malamNaik,
        circularTrackColor: NapakColors.malamNaik,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NapakColors.malam,
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
      // Warna teks dibalik, sisanya persis sama — tipografi Napak tidak
      // berubah hanya karena latarnya gelap.
      final terang = _textTheme();
      return terang.apply(
        bodyColor: NapakColors.base,
        displayColor: NapakColors.base,
      );
    }

    return TextTheme(
      // Judul sengaja lebih berat dan lebih rapat daripada bawaan Material.
      // Versi pertama Napak memakai berat sedang di mana-mana, dan hasilnya
      // rapi tapi tanpa suara — tidak ada yang terbaca sebagai "ini
      // perjalananmu", semuanya terbaca sebagai keterangan.
      displaySmall: heading.displaySmall?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.18,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: heading.titleMedium?.copyWith(
        color: NapakColors.textPrimary,
        fontWeight: FontWeight.w700,
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
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      labelMedium: body.labelMedium?.copyWith(color: NapakColors.textSecondary),
    );
  }
}
