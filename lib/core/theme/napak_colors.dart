import 'package:flutter/material.dart';

/// Palet Napak.
///
/// Semua warna di aplikasi ini berasal dari sini. Kalau sebuah komponen butuh
/// warna yang belum ada, warnanya ditambahkan ke kelas ini dulu — bukan
/// dituliskan langsung di widget. Begitu satu `Color(0xFF...)` lepas berkeliaran
/// di halaman, ketenangan palet ini mulai bocor.
///
/// Semuanya pastel dan rendah saturasi. Tidak ada neon di Napak.
abstract final class NapakColors {
  /// Warna utama Napak. Tombol utama, elemen aktif, garis rute di peta.
  static const primary = Color(0xFFA8C8E8);

  /// Teks penting, ikon aktif, border elemen utama.
  static const deepAccent = Color(0xFF5C87B0);

  /// Background kartu dan elemen sekunder.
  static const softSky = Color(0xFFD6E8F5);

  /// Background utama aplikasi — nyaris putih, dengan sentuhan biru sangat halus.
  static const base = Color(0xFFF5F9FC);

  /// Aksen hangat untuk elemen bertema lokal dan mudik.
  ///
  /// Dipakai sesekali saja, sebagai penyeimbang supaya dominasi biru tidak
  /// terasa dingin. Bukan warna kedua yang dipakai di mana-mana.
  static const warmNeutral = Color(0xFFF0E9DE);

  /// Teks utama. Biru gelap keabu-abuan, sengaja bukan hitam pekat.
  static const textPrimary = Color(0xFF2E3B4E);

  /// Turunan textPrimary untuk keterangan dan label sekunder.
  static const textSecondary = Color(0xFF6B7A8F);

  /// Teks di atas permukaan gelap atau tombol deepAccent.
  static const textOnDeep = Color(0xFFF5F9FC);

  /// Garis pemisah tipis. Nyaris tak terlihat, memang begitu maksudnya.
  static const divider = Color(0xFFE2ECF4);

  /// Untuk hal yang perlu perhatian — tetap desaturasi, tidak berteriak merah.
  static const attention = Color(0xFFC08A8A);

  /// Untuk konfirmasi lembut.
  static const affirm = Color(0xFF8FB8A8);

  /// Gradasi garis rute di peta: dari yang sudah lama dilalui menuju yang terbaru.
  ///
  /// Arahnya deepAccent → primary, memberi kesan jejak yang mengalir dan
  /// menipis, bukan garis datar yang kaku.
  static const routeGradient = [deepAccent, primary];
}
