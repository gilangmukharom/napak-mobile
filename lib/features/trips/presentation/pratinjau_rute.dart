import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';

/// Pratinjau bentuk rute untuk kartu di daftar perjalanan.
///
/// Digambar sendiri dengan CustomPaint, bukan MapLibre. Alasannya bukan gaya:
/// sepuluh kartu berarti sepuluh instance peta, masing-masing dengan konteks
/// GL, tile yang diunduh, dan memorinya sendiri — beranda akan tersendat dan
/// baterai terkuras hanya untuk menggulir daftar.
///
/// Yang dibutuhkan mata di ukuran sekecil ini memang cuma bentuknya. Apakah
/// rutenya lurus panjang, berkelok naik gunung, atau berputar mengelilingi
/// kota — itu terbaca tanpa satu nama jalan pun.
class PratinjauRute extends StatelessWidget {
  const PratinjauRute({
    required this.titik,
    this.tinggi = 156,
    this.warna,
    this.latar,
    this.animasikan = true,
    super.key,
  });

  final List<({double lat, double lng})> titik;
  final double tinggi;

  /// Warna tunggal untuk rute anggota Trip Bareng. Kalau null, dipakai
  /// gradasi khas Tourvella.
  final Color? warna;

  /// Warna latar di belakang garisnya. Diisi `Colors.transparent` kalau
  /// pratinjaunya digambar di atas foto sampul, supaya fotonya tidak
  /// tertutup blok pastel.
  final Color? latar;

  final bool animasikan;

  @override
  Widget build(BuildContext context) {
    if (titik.length < 2) {
      return _PratinjauKosong(tinggi: tinggi);
    }

    return Container(
      height: tinggi,
      width: double.infinity,
      color: latar ?? TourvellaColors.softSky,
      child: animasikan
          // Rutenya menggambar dirinya sendiri dari titik berangkat ke titik
          // sampai, bukan sekadar memudar masuk. Gerakan itu yang membuat
          // kartunya terbaca sebagai perjalanan, bukan sebagai gambar.
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: TourvellaMotion.lambat + TourvellaMotion.sedang,
              curve: TourvellaMotion.mengalir,
              builder: (context, t, _) => CustomPaint(
                painter: _PelukisPratinjau(
                  titik: titik,
                  warna: warna,
                  progres: t,
                ),
                size: Size.infinite,
              ),
            )
          : CustomPaint(
              painter: _PelukisPratinjau(titik: titik, warna: warna),
              size: Size.infinite,
            ),
    );
  }
}

class _PelukisPratinjau extends CustomPainter {
  _PelukisPratinjau({required this.titik, this.warna, this.progres = 1});

  final List<({double lat, double lng})> titik;
  final Color? warna;

  /// Seberapa jauh garisnya sudah tergambar, 0..1.
  final double progres;

  @override
  void paint(Canvas canvas, Size size) {
    const tepi = 22.0;

    var minLat = titik.first.lat;
    var maxLat = titik.first.lat;
    var minLng = titik.first.lng;
    var maxLng = titik.first.lng;

    for (final t in titik) {
      minLat = math.min(minLat, t.lat);
      maxLat = math.max(maxLat, t.lat);
      minLng = math.min(minLng, t.lng);
      maxLng = math.max(maxLng, t.lng);
    }

    // Rentang minimal supaya rute yang nyaris lurus tidak melar memenuhi
    // bingkai dan terbaca seolah jauh lebih berkelok daripada aslinya.
    final rentangLat = math.max(maxLat - minLat, 1e-5);
    final rentangLng = math.max(maxLng - minLng, 1e-5);

    final lebarPakai = size.width - tepi * 2;
    final tinggiPakai = size.height - tepi * 2;

    // Skala yang sama untuk kedua sumbu: bentuk rutenya harus jujur, tidak
    // dipipihkan demi memenuhi kotak.
    final skala = math.min(lebarPakai / rentangLng, tinggiPakai / rentangLat);

    final geserX = tepi + (lebarPakai - rentangLng * skala) / 2;
    final geserY = tepi + (tinggiPakai - rentangLat * skala) / 2;

    Offset keLayar(({double lat, double lng}) t) => Offset(
      geserX + (t.lng - minLng) * skala,
      // Lintang naik ke utara, sumbu Y layar naik ke bawah.
      geserY + (maxLat - t.lat) * skala,
    );

    final jalur = Path()
      ..moveTo(keLayar(titik.first).dx, keLayar(titik.first).dy);
    for (final t in titik.skip(1)) {
      final p = keLayar(t);
      jalur.lineTo(p.dx, p.dy);
    }

    // Garis dipotong sesuai progres, dan ujungnya diambil dari potongan itu
    // supaya titik sampainya ikut berjalan bersama garisnya.
    final ukur = jalur.computeMetrics().first;
    final panjang = ukur.length * progres.clamp(0.0, 1.0);
    final tergambar = panjang <= 0 ? Path() : ukur.extractPath(0, panjang);
    final ujung = ukur.getTangentForOffset(panjang)?.position;

    // Bayangan tipis di bawah garis memberi kedalaman tanpa menambah warna
    // baru ke palet.
    canvas.drawPath(
      tergambar.shift(const Offset(0, 1.5)),
      Paint()
        ..color = TourvellaColors.deepAccent.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      tergambar,
      Paint()
        ..shader = warna != null
            ? null
            : const LinearGradient(
                colors: TourvellaColors.routeGradient,
              ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..color = warna ?? TourvellaColors.deepAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _titikUjung(canvas, keLayar(titik.first), isAwal: true);
    if (ujung != null) _titikUjung(canvas, ujung, isAwal: false);
  }

  void _titikUjung(Canvas canvas, Offset posisi, {required bool isAwal}) {
    // Titik sampai diberi bara: di ujung sanalah perjalanannya berhenti,
    // dan itu yang dicari mata lebih dulu daripada titik berangkatnya.
    final warnaTitik =
        warna ?? (isAwal ? TourvellaColors.deepAccent : TourvellaColors.ember);

    if (!isAwal) {
      canvas.drawCircle(
        posisi,
        10,
        Paint()..color = warnaTitik.withValues(alpha: 0.18),
      );
    }
    canvas.drawCircle(
      posisi,
      isAwal ? 4.5 : 5,
      Paint()..color = TourvellaColors.base,
    );
    canvas.drawCircle(
      posisi,
      isAwal ? 4.5 : 5,
      Paint()
        ..color = warnaTitik
        ..style = isAwal ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PelukisPratinjau oldDelegate) =>
      oldDelegate.titik != titik ||
      oldDelegate.warna != warna ||
      oldDelegate.progres != progres;
}

class _PratinjauKosong extends StatelessWidget {
  const _PratinjauKosong({required this.tinggi});

  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      width: double.infinity,
      color: TourvellaColors.softSky,
      alignment: Alignment.center,
      child: const Icon(
        Icons.timeline_rounded,
        size: 26,
        color: TourvellaColors.primary,
      ),
    );
  }
}
