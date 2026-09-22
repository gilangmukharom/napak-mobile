import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tourvella_colors.dart';

/// Tanda Tourvella: huruf T dari jalan berkelok yang menuju horizon.
///
/// Palangnya horizon, batangnya jalan yang menyempit ke kejauhan (jalan yang
/// datang ke arah kita), dan matahari tujuan terbit di belakangnya.
///
/// Geometrinya sama persis dengan `branding/buat-logo.mjs`, yang membuat ikon
/// aplikasi. Ubah salah satu, ubah juga yang lain — ikon di layar beranda HP
/// dan logo di layar pembuka harus bentuk yang sama.
///
/// [progres] 0..1 menggambar tandanya bertahap: jalan tumbuh dari bawah,
/// palang horizon membentang dari tengah, lalu mataharinya terbit. 1 berarti
/// tanda utuh, tanpa animasi.
class LogoTourvella extends StatelessWidget {
  const LogoTourvella({
    this.ukuran = 96,
    this.progres = 1,
    this.gelap = true,
    this.bukit = false,
    super.key,
  });

  final double ukuran;
  final double progres;

  /// true untuk di atas kanvas malam (jalan bara), false untuk latar terang
  /// (jalan malam, matahari bara).
  final bool gelap;

  /// Punggungan rimba di bawah jalan, seperti di ikon aplikasi.
  final bool bukit;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: ukuran,
      child: CustomPaint(
        painter: _PelukisLogo(progres: progres, gelap: gelap, bukit: bukit),
      ),
    );
  }
}

class _PelukisLogo extends CustomPainter {
  _PelukisLogo({
    required this.progres,
    required this.gelap,
    required this.bukit,
  });

  final double progres;
  final bool gelap;
  final bool bukit;

  // Kotak 1024, sama dengan buat-logo.mjs.
  static const _p0 = Offset(540, 1080);
  static const _p1 = Offset(446, 872);
  static const _p2 = Offset(680, 600);
  static const _p3 = Offset(512, 336);
  static const _lebarBawah = 210.0;
  static const _lebarAtas = 64.0;
  static const _horizonY = 330.0;
  static const _palangX1 = 244.0;
  static const _palangX2 = 780.0;
  static const _palangTebal = 96.0;
  static const _matahariY = 238.0;
  static const _matahariR = 64.0;

  static Offset _kubik(double t) {
    final u = 1 - t;
    return _p0 * (u * u * u) +
        _p1 * (3 * u * u * t) +
        _p2 * (3 * u * t * t) +
        _p3 * (t * t * t);
  }

  static Offset _turunan(double t) {
    final u = 1 - t;
    return (_p1 - _p0) * (3 * u * u) +
        (_p2 - _p1) * (6 * u * t) +
        (_p3 - _p2) * (3 * t * t);
  }

  /// Bagian animasi di antara [a] dan [b], dipetakan ulang ke 0..1.
  double _tahap(double a, double b) =>
      ((progres - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas
      ..save()
      ..scale(s)
      // Tanda tanpa bukit dipotong di bawah kanvas; jalannya berakhir di tepi.
      ..clipRect(const Rect.fromLTWH(0, 0, 1024, 1024));

    final jalan = gelap ? TourvellaColors.ember : TourvellaColors.malam;
    final marka = gelap ? TourvellaColors.malam : TourvellaColors.base;
    final matahari = gelap ? TourvellaColors.emberRedup : TourvellaColors.ember;

    final tJalan = Curves.easeInOutCubic.transform(_tahap(0, 0.55));
    final tPalang = Curves.easeOutCubic.transform(_tahap(0.42, 0.72));
    final tMatahari = Curves.easeOutBack.transform(_tahap(0.62, 1));

    // Matahari terbit dari balik horizon — digambar sebelum palang, jadi
    // palangnya yang menutupi separuh bawahnya.
    if (tMatahari > 0) {
      final y = _horizonY + (_matahariY - _horizonY) * tMatahari;
      canvas.drawCircle(
        Offset(512, y),
        _matahariR * math.min(1, 0.6 + 0.4 * tMatahari),
        Paint()..color = matahari,
      );
    }

    if (bukit) {
      final dekat = Path()
        ..moveTo(0, 1024)
        ..lineTo(0, 820)
        ..cubicTo(170, 770, 300, 836, 460, 806)
        ..cubicTo(640, 772, 800, 846, 1024, 796)
        ..lineTo(1024, 1024)
        ..close();
      canvas.drawPath(dekat, Paint()..color = TourvellaColors.rimba);
    }

    if (tJalan > 0) {
      // Badan jalan: poligon dari dua tepi, menyempit ke horizon.
      const n = 64;
      final akhir = (n * tJalan).ceil();
      final kiri = <Offset>[];
      final kanan = <Offset>[];
      for (var i = 0; i <= akhir; i++) {
        final t = math.min(i / n, tJalan);
        final p = _kubik(t);
        final d = _turunan(t);
        final pj = d.distance == 0 ? 1.0 : d.distance;
        final normal = Offset(-d.dy / pj, d.dx / pj);
        final w =
            (_lebarBawah - (_lebarBawah - _lebarAtas) * math.pow(t, 0.8)) / 2;
        kiri.add(p + normal * w);
        kanan.add(p - normal * w);
      }
      final badan = Path()..addPolygon([...kiri, ...kanan.reversed], true);
      canvas.drawPath(
        badan,
        Paint()
          ..color = jalan
          ..style = PaintingStyle.fill,
      );

      // Marka putus-putus di garis tengah, sepanjang jalan yang sudah ada.
      final tengah = Path()
        ..moveTo(_p0.dx, _p0.dy)
        ..cubicTo(_p1.dx, _p1.dy, _p2.dx, _p2.dy, _p3.dx, _p3.dy);
      final ukur = tengah.computeMetrics().first;
      final sampai = ukur.length * tJalan;
      final catMarka = Paint()
        ..color = marka
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round;
      for (var d = 0.0; d < sampai; d += 84) {
        canvas.drawPath(
          ukur.extractPath(d, math.min(d + 40, sampai)),
          catMarka,
        );
      }
    }

    if (tPalang > 0) {
      // Horizon membentang dari tengah ke dua sisi.
      final setengah = (_palangX2 - _palangX1) / 2 * tPalang;
      canvas.drawLine(
        Offset(512 - setengah, _horizonY),
        Offset(512 + setengah, _horizonY),
        Paint()
          ..color = jalan
          ..strokeWidth = _palangTebal
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PelukisLogo lama) =>
      lama.progres != progres || lama.gelap != gelap || lama.bukit != bukit;
}

/// Logo + nama, untuk layar masuk dan tempat lain yang butuh identitas utuh.
class WordmarkTourvella extends StatelessWidget {
  const WordmarkTourvella({
    this.ukuranLogo = 56,
    this.gelap = true,
    this.progres = 1,
    super.key,
  });

  final double ukuranLogo;
  final bool gelap;
  final double progres;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoTourvella(ukuran: ukuranLogo, progres: progres, gelap: gelap),
        SizedBox(width: ukuranLogo * 0.22),
        Opacity(
          opacity: ((progres - 0.5) / 0.5).clamp(0.0, 1.0),
          child: Text(
            'Tourvella',
            style: text.headlineMedium?.copyWith(
              color: gelap ? TourvellaColors.base : TourvellaColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ],
    );
  }
}
