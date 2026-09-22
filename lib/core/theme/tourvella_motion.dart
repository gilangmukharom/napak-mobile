import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Sistem gerak Tourvella.
///
/// Sama seperti warna: gerak juga punya palet. Kalau tiap layar memilih durasi
/// dan kurvanya sendiri, aplikasinya terasa gelisah — satu tombol memantul,
/// tombol sebelahnya meluncur, dan tidak ada yang terasa satu keluarga.
///
/// Semua angka di sini berasal dari satu pertimbangan: gerak di Tourvella harus
/// terasa seperti sesuatu yang *mengalir*, bukan yang *melompat*. Perjalanan
/// tidak melompat.
abstract final class TourvellaMotion {
  // --- Durasi ---

  /// Umpan balik sentuhan. Harus lebih cepat dari yang bisa disadari mata,
  /// supaya terasa seperti bahan yang menekan balik, bukan animasi.
  static const kilat = Duration(milliseconds: 120);

  /// Perubahan kecil dalam satu layar: kartu mengembang, ikon berganti.
  static const cepat = Duration(milliseconds: 220);

  /// Bawaan untuk sebagian besar hal.
  static const sedang = Duration(milliseconds: 380);

  /// Perpindahan halaman dan hal-hal yang perlu diikuti mata.
  static const lambat = Duration(milliseconds: 520);

  /// Layar pembuka. Satu-satunya tempat Tourvella boleh menahan orang sebentar.
  static const pembuka = Duration(milliseconds: 2000);

  /// Kendaraan di peta meluncur ke posisi barunya, bukan melompat.
  ///
  /// Posisi baru datang tiap belasan detik; sepanjang ini cukup untuk terbaca
  /// sebagai gerak, dan cukup pendek supaya peta diam lagi — GeoJSON hanya
  /// diperbarui selama luncuran berlangsung, tidak terus-menerus.
  static const luncurKendaraan = Duration(milliseconds: 1400);

  /// Jeda antar bingkai luncuran. 24 bingkai per detik: halus di mata, tapi
  /// separuh beban 60 fps untuk jembatan ke peta native.
  static const bingkaiPeta = Duration(milliseconds: 42);

  /// Jeda antar elemen pada daftar yang muncul bertahap.
  static const antreanDaftar = Duration(milliseconds: 55);

  // --- Kurva ---

  /// Kurva utama. Mulai tegas, berhenti lembut — persis rasanya benda nyata
  /// yang didorong lalu mengendap.
  static const mengalir = Curves.easeOutCubic;

  /// Untuk yang masuk dan keluar dalam satu tarikan.
  static const masukKeluar = Curves.easeInOutCubic;

  /// Sedikit memantul di ujung. Dipakai hemat — hanya untuk momen yang
  /// memang pantas dirayakan, seperti perjalanan yang baru saja ditutup.
  static const memantul = Curves.easeOutBack;

  /// Untuk yang pergi meninggalkan layar.
  static const pergi = Curves.easeInCubic;

  // --- Jarak geser ---

  /// Seberapa jauh elemen naik saat muncul. Cukup untuk terbaca sebagai
  /// gerak, tidak cukup untuk terasa berisik.
  static const naikMasuk = 24.0;
}

/// Transisi perpindahan halaman.
///
/// Halaman baru meluncur dari kanan sambil memudar masuk, yang lama sedikit
/// mundur ke kiri. Arahnya menegaskan hubungan: yang baru datang dari depan,
/// yang lama menunggu di belakang.
class GeserMasuk<T> extends CustomTransitionPage<T> {
  GeserMasuk({required super.child, super.key})
    : super(
        transitionDuration: TourvellaMotion.sedang,
        reverseTransitionDuration: TourvellaMotion.cepat,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final masuk = CurvedAnimation(
            parent: animation,
            curve: TourvellaMotion.mengalir,
            reverseCurve: TourvellaMotion.pergi,
          );
          final mundur = CurvedAnimation(
            parent: secondaryAnimation,
            curve: TourvellaMotion.mengalir,
          );

          return SlideTransition(
            position: Tween(
              begin: const Offset(0.16, 0),
              end: Offset.zero,
            ).animate(masuk),
            child: FadeTransition(
              opacity: masuk,
              child: SlideTransition(
                position: Tween(
                  begin: Offset.zero,
                  end: const Offset(-0.08, 0),
                ).animate(mundur),
                child: child,
              ),
            ),
          );
        },
      );
}

/// Transisi untuk lembar dan layar yang datang dari bawah.
class NaikMasuk<T> extends CustomTransitionPage<T> {
  NaikMasuk({required super.child, super.key})
    : super(
        transitionDuration: TourvellaMotion.sedang,
        reverseTransitionDuration: TourvellaMotion.cepat,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final masuk = CurvedAnimation(
            parent: animation,
            curve: TourvellaMotion.mengalir,
            reverseCurve: TourvellaMotion.pergi,
          );

          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(masuk),
            child: FadeTransition(opacity: masuk, child: child),
          );
        },
      );
}

/// Berpindah antar tab tanpa arah — memudar silang di tempat.
///
/// Tab itu sejajar, tidak ada yang "lebih dalam" dari yang lain, jadi gerak
/// menyamping justru membingungkan.
class MemudarSilang<T> extends CustomTransitionPage<T> {
  MemudarSilang({required super.child, super.key})
    : super(
        transitionDuration: TourvellaMotion.cepat,
        reverseTransitionDuration: TourvellaMotion.cepat,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: TourvellaMotion.masukKeluar,
            ),
            child: child,
          );
        },
      );
}

/// Tag Hero untuk peta sebuah perjalanan.
///
/// Dipakai di dua tempat — kartu di beranda dan peta besar di halaman detail —
/// supaya petanya terbang di antara keduanya alih-alih berkedip berganti.
String tagPetaTrip(String tripId) => 'peta-trip-$tripId';
