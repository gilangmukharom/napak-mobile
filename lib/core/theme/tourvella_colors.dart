import 'package:flutter/material.dart';

/// Palet Tourvella.
///
/// Semua warna di aplikasi ini berasal dari sini. Kalau sebuah komponen butuh
/// warna yang belum ada, warnanya ditambahkan ke kelas ini dulu — bukan
/// dituliskan langsung di widget. Begitu satu `Color(0xFF...)` lepas berkeliaran
/// di halaman, ketenangan palet ini mulai bocor.
///
/// Dasarnya tetap pastel biru dan rendah saturasi — tidak ada neon di Tourvella.
/// Di atasnya ada tiga warna ekspedisi: `malam`, `ember`, dan `rimba`.
///
/// Tiga itu ditambahkan setelah paletnya terbukti terlalu lembut untuk
/// aplikasi tentang perjalanan: semuanya terang, semuanya sejuk, dan
/// akibatnya tidak ada yang terasa seperti berangkat subuh-subuh. Pastel
/// tetap memegang permukaan tenang — daftar, kartu, teks. Warna ekspedisi
/// memegang saat-saat berangkat dan malam sebelum jalan.
abstract final class TourvellaColors {
  /// Warna utama Tourvella. Tombol utama, elemen aktif, garis rute di peta.
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

  // --- Warna ekspedisi ---

  /// Kanvas malam. Latar layar rekam, peta gelap, cerita, Jejak Nusantara.
  ///
  /// Lebih gelap dan lebih pekat daripada [textPrimary]: kalau latarnya cuma
  /// setingkat warna teks, teks putih di atasnya tidak pernah benar-benar
  /// menyala.
  static const malam = Color(0xFF17202B);

  /// Selapis di atas [malam] untuk kartu dan panel di layar gelap.
  static const malamNaik = Color(0xFF212C3A);

  /// Bara: matahari terbit, lampu sein, jarum odometer, stempel pencapaian.
  ///
  /// Satu-satunya warna hangat yang boleh berteriak sedikit, dan justru
  /// karena itu dipakai hemat — untuk hal yang sedang terjadi sekarang.
  static const ember = Color(0xFFD98A4E);

  /// Bara yang lebih redup, untuk latar dan garis di atas kanvas terang.
  static const emberRedup = Color(0xFFE8C4A0);

  /// Rimba: hutan, kebun teh, jalur gunung. Pasangan gelap dari [affirm].
  static const rimba = Color(0xFF2C5F52);

  /// Garis kontur peta topografi yang digambar di latar.
  static const kontur = Color(0xFF3A4A5E);

  /// Gradasi garis rute di peta: dari yang sudah lama dilalui menuju yang terbaru.
  ///
  /// Arahnya deepAccent → primary, memberi kesan jejak yang mengalir dan
  /// menipis, bukan garis datar yang kaku.
  static const routeGradient = [deepAccent, primary];

  /// Gradasi ekspedisi: langit subuh di atas punggungan gunung.
  static const langitSubuh = [malam, Color(0xFF2E3B4E), ember];

  /// Gradasi kanvas malam, untuk latar layar aksi.
  static const kanvasMalam = [malam, malamNaik];
}
