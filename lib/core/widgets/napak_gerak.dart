import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/napak_motion.dart';

/// Angka yang berjalan naik sampai nilainya.
///
/// Dipakai untuk jarak dan jumlah di recap. Angka yang muncul begitu saja
/// hanya terbaca sebagai data; angka yang berjalan naik terbaca sebagai
/// sesuatu yang dikumpulkan — dan itulah yang sebenarnya terjadi sepanjang
/// tahun.
class AngkaBerjalan extends StatelessWidget {
  const AngkaBerjalan({
    required this.nilai,
    this.desimal = 0,
    this.gaya,
    this.jeda = Duration.zero,
    this.durasi = const Duration(milliseconds: 1100),
    super.key,
  });

  final double nilai;
  final int desimal;
  final TextStyle? gaya;
  final Duration jeda;
  final Duration durasi;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: nilai),
      duration: durasi,
      // Melambat tajam di ujung: angkanya berlari lalu mengendap di nilai
      // akhirnya, bukan berhenti mendadak.
      curve: Curves.easeOutExpo,
      builder: (context, t, _) => Text(
        NumberFormat.decimalPatternDigits(
          locale: 'id_ID',
          decimalDigits: desimal,
        ).format(t),
        style: gaya,
      ),
    );
  }
}

/// Membuat anak-anaknya muncul satu per satu, bukan sekaligus.
///
/// Daftar yang muncul serentak terasa seperti halaman yang di-refresh.
/// Muncul bertahap terasa seperti sesuatu yang sedang disusun — dan mata
/// jadi punya waktu mengikuti dari atas ke bawah.
class MunculBertahap extends StatelessWidget {
  const MunculBertahap({
    required this.indeks,
    required this.child,
    this.jarakGeser = NapakMotion.naikMasuk,
    super.key,
  });

  final int indeks;
  final Widget child;
  final double jarakGeser;

  @override
  Widget build(BuildContext context) {
    // Antreannya dibatasi: elemen kesepuluh ke bawah tidak perlu menunggu
    // setengah detik lebih, karena orang sudah menggulir duluan.
    final jeda = NapakMotion.antreanDaftar * (indeks.clamp(0, 8));

    return TweenAnimationBuilder<double>(
      key: ValueKey(indeks),
      tween: Tween(begin: 0, end: 1),
      duration: NapakMotion.lambat + jeda,
      curve: Interval(
        jeda.inMilliseconds / (NapakMotion.lambat + jeda).inMilliseconds,
        1,
        curve: NapakMotion.mengalir,
      ),
      builder: (context, t, anak) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * jarakGeser),
          child: anak,
        ),
      ),
      child: child,
    );
  }
}

/// Titik yang berdenyut pelan. Penanda "sedang berjalan".
class TitikBerdenyut extends StatefulWidget {
  const TitikBerdenyut({required this.warna, this.ukuran = 10, super.key});

  final Color warna;
  final double ukuran;

  @override
  State<TitikBerdenyut> createState() => _TitikBerdenyutState();
}

class _TitikBerdenyutState extends State<TitikBerdenyut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.ukuran * 2.6,
      width: widget.ukuran * 2.6,
      child: AnimatedBuilder(
        animation: _kendali,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_kendali.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Riak yang melebar lalu menghilang — seperti tetesan di air.
              Container(
                height: widget.ukuran * (1 + t * 1.6),
                width: widget.ukuran * (1 + t * 1.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.warna.withValues(alpha: (1 - t) * 0.35),
                ),
              ),
              Container(
                height: widget.ukuran,
                width: widget.ukuran,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.warna,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Garis rute yang menggambar dirinya sendiri.
///
/// Dipakai di layar pembuka dan di keadaan kosong. Bentuknya sepotong jejak,
/// bukan logo — merek Napak memang bukan lambang, melainkan garis perjalanan.
class JejakMenggambar extends StatelessWidget {
  const JejakMenggambar({
    required this.progres,
    required this.gradasi,
    this.tebal = 3.5,
    super.key,
  });

  final double progres;
  final List<Color> gradasi;
  final double tebal;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PelukisJejak(progres: progres, gradasi: gradasi, tebal: tebal),
      size: Size.infinite,
    );
  }
}

class _PelukisJejak extends CustomPainter {
  _PelukisJejak({
    required this.progres,
    required this.gradasi,
    required this.tebal,
  });

  final double progres;
  final List<Color> gradasi;
  final double tebal;

  @override
  void paint(Canvas canvas, Size size) {
    if (progres <= 0) return;

    final jalur = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.05,
        size.width * 0.40,
        size.height * 1.05,
        size.width * 0.64,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.08,
        size.width * 0.88,
        size.height * 0.18,
        size.width,
        size.height * 0.26,
      );

    // PathMetric memotong jalur pada panjang tertentu, jadi garisnya benar-
    // benar tergambar bertahap — bukan sekadar muncul memudar.
    final ukur = jalur.computeMetrics().first;
    final potongan = ukur.extractPath(0, ukur.length * progres);

    canvas.drawPath(
      potongan,
      Paint()
        ..shader = LinearGradient(
          colors: gradasi,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = tebal
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Titik di ujung yang sedang menggambar, seperti pena yang berjalan.
    final ujung = ukur.getTangentForOffset(ukur.length * progres)?.position;
    if (ujung != null) {
      canvas.drawCircle(ujung, tebal * 1.5, Paint()..color = gradasi.last);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisJejak oldDelegate) =>
      oldDelegate.progres != progres;
}
