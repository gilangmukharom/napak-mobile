import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'tourvella_colors.dart';

/// Tekstur ekspedisi: kontur topografi, butiran kertas, siluet punggungan.
///
/// Semuanya **digambar**, bukan gambar tempelan. Tiga alasannya: ukurannya
/// mengikuti layar mana pun tanpa jadi buram, bisa dianimasikan (kontur
/// bergeser paralaks saat digulir), dan tidak menambah satu megabyte pun ke
/// ukuran aplikasi.

/// Garis kontur peta topografi.
///
/// Bukan kontur sungguhan dari data ketinggian — ini gelombang berlapis yang
/// dibentuk dari beberapa sinus. Yang dicari kesannya: latar yang terbaca
/// sebagai peta, bukan bidang warna kosong. Kontur sungguhan di belakang
/// tulisan justru ramai dan mengganggu.
class KonturTopografi extends StatelessWidget {
  const KonturTopografi({
    this.warna = TourvellaColors.kontur,
    this.opasitas = 0.5,
    this.jumlahGaris = 9,
    this.geser = 0,
    this.benih = 7,
    super.key,
  });

  final Color warna;
  final double opasitas;
  final int jumlahGaris;

  /// Pergeseran vertikal, untuk paralaks saat halaman digulir.
  final double geser;

  final int benih;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PelukisKontur(
          warna: warna.withValues(alpha: opasitas),
          jumlah: jumlahGaris,
          geser: geser,
          benih: benih,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PelukisKontur extends CustomPainter {
  _PelukisKontur({
    required this.warna,
    required this.jumlah,
    required this.geser,
    required this.benih,
  });

  final Color warna;
  final int jumlah;
  final double geser;
  final int benih;

  @override
  void paint(Canvas canvas, Size size) {
    final kuas = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = warna;

    final acak = math.Random(benih);
    // Tiga gelombang dengan panjang berbeda; yang dipakai sama untuk semua
    // garis supaya garisnya sejajar seperti kontur sungguhan.
    final f1 = 1.2 + acak.nextDouble() * 0.8;
    final f2 = 2.7 + acak.nextDouble() * 1.4;
    final f3 = 5.1 + acak.nextDouble() * 2.0;
    final p1 = acak.nextDouble() * math.pi * 2;
    final p2 = acak.nextDouble() * math.pi * 2;
    final p3 = acak.nextDouble() * math.pi * 2;

    final jarak = size.height / (jumlah - 1);
    final amplitudo = jarak * 0.9;

    for (var i = 0; i < jumlah; i++) {
      final dasar = i * jarak + (geser % jarak);
      // Makin ke bawah, gelombangnya makin dalam — punggungan terasa
      // mendekat, bukan berulang datar.
      final kedalaman = amplitudo * (0.45 + 0.55 * (i / jumlah));
      final jalur = Path();

      for (var x = 0.0; x <= size.width + 4; x += 4) {
        final t = x / size.width;
        final y =
            dasar +
            math.sin(t * math.pi * f1 + p1) * kedalaman * 0.55 +
            math.sin(t * math.pi * f2 + p2) * kedalaman * 0.28 +
            math.sin(t * math.pi * f3 + p3) * kedalaman * 0.12;
        x == 0 ? jalur.moveTo(x, y) : jalur.lineTo(x, y);
      }
      canvas.drawPath(jalur, kuas);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisKontur lama) =>
      lama.geser != geser || lama.warna != warna || lama.jumlah != jumlah;
}

/// Butiran halus, seperti kertas peta lama.
///
/// Bidang warna rata di layar besar terlihat seperti plastik. Butiran tipis
/// membuatnya terasa seperti bahan — dan karena sangat samar, tidak ada yang
/// menyadarinya kecuali saat dimatikan.
class ButiranKertas extends StatelessWidget {
  const ButiranKertas({
    this.opasitas = 0.05,
    this.kerapatan = 900,
    this.warna = Colors.white,
    super.key,
  });

  final double opasitas;
  final int kerapatan;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PelukisButiran(
            warna: warna.withValues(alpha: opasitas),
            kerapatan: kerapatan,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PelukisButiran extends CustomPainter {
  _PelukisButiran({required this.warna, required this.kerapatan});

  final Color warna;
  final int kerapatan;

  @override
  void paint(Canvas canvas, Size size) {
    // Benihnya tetap: butirannya tidak boleh berkedip tiap kali digambar ulang.
    final acak = math.Random(42);
    final titik = <Offset>[
      for (var i = 0; i < kerapatan; i++)
        Offset(acak.nextDouble() * size.width, acak.nextDouble() * size.height),
    ];
    canvas.drawPoints(
      PointMode.points,
      titik,
      Paint()
        ..color = warna
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PelukisButiran lama) => lama.warna != warna;
}

/// Siluet punggungan gunung, berlapis.
///
/// Tiap lapis bisa digeser dengan kecepatan berbeda saat halaman digulir —
/// yang dekat bergerak lebih cepat daripada yang jauh, seperti memandang dari
/// jendela bus.
class SiluetGunung extends StatelessWidget {
  const SiluetGunung({
    this.geser = 0,
    this.warna = const [TourvellaColors.malamNaik, TourvellaColors.malam],
    this.benih = 3,
    super.key,
  });

  final double geser;
  final List<Color> warna;
  final int benih;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PelukisGunung(geser: geser, warna: warna, benih: benih),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PelukisGunung extends CustomPainter {
  _PelukisGunung({
    required this.geser,
    required this.warna,
    required this.benih,
  });

  final double geser;
  final List<Color> warna;
  final int benih;

  @override
  void paint(Canvas canvas, Size size) {
    for (var lapis = 0; lapis < warna.length; lapis++) {
      final acak = math.Random(benih + lapis * 31);
      // Lapisan belakang lebih tinggi, lebih landai, dan bergerak lebih
      // pelan — itu yang membuat kedalamannya terbaca.
      final jauh = (warna.length - lapis) / warna.length;
      final dasar = size.height * (0.45 + lapis * 0.18);
      final tinggi = size.height * (0.28 - lapis * 0.05);
      final kecepatan = 0.25 + lapis * 0.45;

      final jalur = Path()..moveTo(-20, size.height + 10);
      final puncak = 4 + lapis;
      for (var i = 0; i <= puncak; i++) {
        final x = -20 + (size.width + 40) * (i / puncak);
        final y =
            dasar -
            tinggi * (0.35 + acak.nextDouble() * 0.65) +
            geser * kecepatan * jauh;
        i == 0 ? jalur.lineTo(x, y) : _punggungan(jalur, x, y);
      }
      jalur
        ..lineTo(size.width + 20, size.height + 10)
        ..close();

      canvas.drawPath(jalur, Paint()..color = warna[lapis]);
    }
  }

  /// Punggungan digambar dengan kurva, bukan garis patah: gunung tidak
  /// pernah setajam grafik.
  void _punggungan(Path jalur, double x, double y) {
    final dari = jalur.getBounds().right;
    jalur.quadraticBezierTo((dari + x) / 2, y - 12, x, y);
  }

  @override
  bool shouldRepaint(covariant _PelukisGunung lama) => lama.geser != geser;
}

/// Latar ekspedisi lengkap: kanvas malam, kontur, butiran, dan isinya.
///
/// Satu widget supaya layar gelap di seluruh aplikasi punya dasar yang sama
/// persis, bukan tiga layar yang masing-masing menyusun gradasinya sendiri.
class LatarEkspedisi extends StatelessWidget {
  const LatarEkspedisi({
    required this.child,
    this.kontur = true,
    this.gunung = false,
    this.geser = 0,
    super.key,
  });

  final Widget child;
  final bool kontur;
  final bool gunung;
  final double geser;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: TourvellaColors.kanvasMalam,
            ),
          ),
        ),
        if (kontur)
          IgnorePointer(
            child: KonturTopografi(opasitas: 0.32, geser: geser * 0.4),
          ),
        if (gunung) SiluetGunung(geser: geser),
        const ButiranKertas(opasitas: 0.035),
        child,
      ],
    );
  }
}
