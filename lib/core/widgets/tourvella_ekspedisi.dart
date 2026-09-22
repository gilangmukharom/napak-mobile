import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/napak_colors.dart';
import '../theme/napak_tekstur.dart';
import '../theme/napak_motion.dart';

/// Komponen bertema ekspedisi: odometer, kompas, stempel, label kapital.
///
/// Semuanya soal karakter, bukan hiasan. Angka yang berputar seperti odometer
/// motor terbaca sebagai jarak yang ditempuh; angka yang tiba-tiba berganti
/// terbaca sebagai data.

/// Angka bergaya odometer: tiap digit berputar naik saat berubah.
class Odometer extends StatelessWidget {
  const Odometer({
    required this.nilai,
    this.desimal = 0,
    this.gaya,
    this.satuan,
    super.key,
  });

  final double nilai;
  final int desimal;
  final TextStyle? gaya;

  /// Satuan kecil di belakang angka, mis. "km". Tidak ikut berputar.
  final String? satuan;

  @override
  Widget build(BuildContext context) {
    final teks = nilai.toStringAsFixed(desimal).replaceAll('.', ',');
    final gayaAngka = (gaya ?? Theme.of(context).textTheme.displaySmall)
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final (i, huruf) in teks.split('').indexed)
          _Digit(huruf: huruf, gaya: gayaAngka, posisi: i),
        if (satuan != null) ...[
          const SizedBox(width: 4),
          Text(
            satuan!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: gayaAngka?.color?.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit({required this.huruf, required this.gaya, required this.posisi});

  final String huruf;
  final TextStyle? gaya;
  final int posisi;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: NapakMotion.sedang,
      switchInCurve: NapakMotion.mengalir,
      switchOutCurve: NapakMotion.pergi,
      transitionBuilder: (anak, animasi) => ClipRect(
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.8),
            end: Offset.zero,
          ).animate(animasi),
          child: FadeTransition(opacity: animasi, child: anak),
        ),
      ),
      // Kunci berisi posisi supaya digit yang tidak berubah tidak ikut
      // berputar saat tetangganya berganti.
      child: Text(huruf, key: ValueKey('$posisi-$huruf'), style: gaya),
    );
  }
}

/// Jarum kompas yang menunjuk satu arah, dengan ayunan seperti kompas asli.
///
/// Kompas sungguhan tidak pernah berhenti persis: jarumnya melewati sasaran
/// sedikit lalu kembali. Itu yang ditiru di sini — tanpa ayunan itu, jarumnya
/// terbaca sebagai panah biasa.
class JarumKompas extends StatefulWidget {
  const JarumKompas({
    required this.arah,
    this.ukuran = 52,
    this.warna = NapakColors.ember,
    this.warnaLatar = NapakColors.malamNaik,
    super.key,
  });

  /// Derajat dari utara, searah jarum jam.
  final double arah;
  final double ukuran;
  final Color warna;
  final Color warnaLatar;

  @override
  State<JarumKompas> createState() => _JarumKompasState();
}

class _JarumKompasState extends State<JarumKompas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ayun = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ayun.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.ukuran,
      height: widget.ukuran,
      child: AnimatedBuilder(
        animation: _ayun,
        builder: (context, anak) {
          // Ayunan kecil yang terus berjalan, di atas putaran ke arah tujuan.
          final goyang = math.sin(_ayun.value * math.pi * 2) * 2.5;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: widget.arah),
            duration: NapakMotion.lambat,
            curve: NapakMotion.memantul,
            builder: (context, arah, _) => CustomPaint(
              painter: _PelukisKompas(
                arah: arah + goyang,
                warna: widget.warna,
                warnaLatar: widget.warnaLatar,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PelukisKompas extends CustomPainter {
  _PelukisKompas({
    required this.arah,
    required this.warna,
    required this.warnaLatar,
  });

  final double arah;
  final Color warna;
  final Color warnaLatar;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = size.center(Offset.zero);
    final jari = size.width / 2;

    canvas
      ..drawCircle(pusat, jari, Paint()..color = warnaLatar)
      ..drawCircle(
        pusat,
        jari - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = warna.withValues(alpha: 0.35),
      );

    // Empat titik mata angin.
    for (var i = 0; i < 4; i++) {
      final sudut = i * math.pi / 2 - math.pi / 2;
      canvas.drawCircle(
        pusat + Offset(math.cos(sudut), math.sin(sudut)) * (jari - 5),
        i == 0 ? 1.8 : 1.1,
        Paint()..color = warna.withValues(alpha: i == 0 ? 0.9 : 0.4),
      );
    }

    canvas
      ..save()
      ..translate(pusat.dx, pusat.dy)
      ..rotate(arah * math.pi / 180);

    final panjang = jari * 0.62;
    // Ujung utara pekat, ekor selatan samar — itu yang membuat arahnya
    // terbaca dalam sekali lihat.
    final utara = Path()
      ..moveTo(0, -panjang)
      ..lineTo(panjang * 0.32, panjang * 0.12)
      ..lineTo(0, -panjang * 0.05)
      ..close();
    final selatan = Path()
      ..moveTo(0, panjang * 0.7)
      ..lineTo(panjang * 0.32, panjang * 0.12)
      ..lineTo(0, -panjang * 0.05)
      ..close();

    canvas
      ..drawPath(utara, Paint()..color = warna)
      ..drawPath(
        utara.transform(Matrix4.diagonal3Values(-1, 1, 1).storage),
        Paint()..color = warna.withValues(alpha: 0.75),
      )
      ..drawPath(selatan, Paint()..color = warna.withValues(alpha: 0.28))
      ..drawPath(
        selatan.transform(Matrix4.diagonal3Values(-1, 1, 1).storage),
        Paint()..color = warna.withValues(alpha: 0.2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _PelukisKompas lama) =>
      lama.arah != arah || lama.warna != warna;
}

/// Stempel paspor: mendarat miring, berputar sedikit, lalu diam.
///
/// Dipakai untuk pencapaian — provinsi pertama, seribu kilometer, mudik
/// kelima. Stempel terasa seperti bukti yang dicap orang, bukan lencana yang
/// dibagikan sistem.
class StempelPencapaian extends StatelessWidget {
  const StempelPencapaian({
    required this.teks,
    this.keterangan,
    this.warna = NapakColors.ember,
    this.miring = -0.12,
    this.tunda = Duration.zero,
    super.key,
  });

  final String teks;
  final String? keterangan;
  final Color warna;
  final double miring;
  final Duration tunda;

  @override
  Widget build(BuildContext context) {
    final isi = Transform.rotate(
      angle: miring,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: warna, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              teks.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: warna,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            if (keterangan != null)
              Text(
                keterangan!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: warna.withValues(alpha: 0.75),
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NapakMotion.lambat + tunda,
      curve: Interval(
        tunda.inMilliseconds / (NapakMotion.lambat + tunda).inMilliseconds,
        1,
        // Mendarat keras lalu memantul sedikit — seperti stempel sungguhan.
        curve: Curves.elasticOut,
      ),
      builder: (context, t, anak) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.4 + 0.6 * t.clamp(0.0, 1.2),
          child: anak,
        ),
      ),
      child: isi,
    );
  }
}

/// Label kapital berjarak: "JEJAK", "252 KM", "SEDANG MEREKAM".
///
/// Huruf kapital renggang membaca seperti papan penunjuk jalan dan pelat
/// nomor — bahasa visual perjalanan, bukan bahasa aplikasi perkantoran.
class LabelKapital extends StatelessWidget {
  const LabelKapital(
    this.teks, {
    this.warna,
    this.ukuran = 11,
    this.tebal = FontWeight.w700,
    super.key,
  });

  final String teks;
  final Color? warna;
  final double ukuran;
  final FontWeight tebal;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks.toUpperCase(),
      style: TextStyle(
        fontSize: ukuran,
        fontWeight: tebal,
        letterSpacing: 2.2,
        color: warna ?? NapakColors.textSecondary,
      ),
    );
  }
}

/// Garis putus-putus seperti jalur di peta.
class PemisahJalur extends StatelessWidget {
  const PemisahJalur({
    this.warna = NapakColors.divider,
    this.tebal = 1.4,
    super.key,
  });

  final Color warna;
  final double tebal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tebal,
      child: LayoutBuilder(
        builder: (context, batas) {
          final jumlah = (batas.maxWidth / 10).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < jumlah; i++)
                SizedBox(
                  width: 5,
                  height: tebal,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: warna,
                      borderRadius: BorderRadius.circular(tebal),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Nilai gulir satu halaman, untuk dipakai paralaks.
///
/// Dipakai begini:
/// ```dart
/// PendengarGulir(
///   builder: (geser) => LatarEkspedisi(geser: geser, child: ...),
/// )
/// ```
class PendengarGulir extends StatefulWidget {
  const PendengarGulir({required this.builder, super.key});

  final Widget Function(double geser) builder;

  @override
  State<PendengarGulir> createState() => _PendengarGulirState();
}

class _PendengarGulirState extends State<PendengarGulir> {
  double _geser = 0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (kabar) {
        // Dibatasi: paralaks yang terus bergerak sampai jauh membuat
        // gunungnya keluar dari layar dan latarnya jadi kosong.
        final geser = (-kabar.metrics.pixels * 0.25).clamp(-90.0, 30.0);
        if ((geser - _geser).abs() > 0.5) setState(() => _geser = geser);
        return false;
      },
      child: widget.builder(_geser),
    );
  }
}

/// Bilah judul bertema ekspedisi.
///
/// Satu tempat untuk kepala halaman di seluruh aplikasi, supaya tiap layar
/// tidak menyusun gradasi dan konturnya sendiri-sendiri. Judulnya di atas
/// kanvas malam dengan keterangan kapital renggang di atasnya — bentuk yang
/// sama dipakai papan penunjuk jalan: tujuan besar, keterangan kecil.
class BilahEkspedisi extends StatelessWidget implements PreferredSizeWidget {
  const BilahEkspedisi({
    required this.judul,
    this.keterangan,
    this.aksi = const <Widget>[],
    this.bawah,
    this.tinggiBawah = 0,
    super.key,
  });

  final String judul;

  /// Baris kapital kecil di atas judul: "12 KABAR BARU", "188 KOTA".
  final String? keterangan;
  final List<Widget> aksi;

  /// Isi tambahan di bawah judul — tab, pencarian, penyaring.
  final Widget? bawah;
  final double tinggiBawah;

  @override
  Size get preferredSize =>
      Size.fromHeight((keterangan == null ? 62 : 78) + tinggiBawah);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NapakColors.malam, NapakColors.malamNaik],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.18, jumlahGaris: 3, benih: 5),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: keterangan == null ? 62 : 78,
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        const BackButton(color: NapakColors.base)
                      else
                        const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (keterangan != null) ...[
                              LabelKapital(
                                keterangan!,
                                warna: NapakColors.emberRedup,
                                ukuran: 10,
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              judul,
                              style: text.titleLarge?.copyWith(
                                color: NapakColors.base,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      ...aksi,
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                if (bawah != null) SizedBox(height: tinggiBawah, child: bawah),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
