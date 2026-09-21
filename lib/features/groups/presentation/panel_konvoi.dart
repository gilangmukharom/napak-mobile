import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../../trips/data/trip_models.dart';

/// Barisan konvoi: rombongan digambar sebagai titik-titik di satu ruas jalan.
///
/// Yang paling depan di kanan, yang lain mundur ke kiri sebanding jarak
/// tempuhnya. Marka jalannya terus bergerak, supaya panel ini terbaca sebagai
/// "sedang jalan" walau angkanya belum berubah.
class PanelKonvoi extends StatelessWidget {
  const PanelKonvoi({required this.kabar, super.key});

  final KabarKonvoi kabar;

  static String _jarak(double m) {
    if (m < 1000) return '${(m / 10).round() * 10} m';
    final km = m / 1000;
    return km >= 10
        ? '${km.round()} km'
        : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final adaTertinggal = kabar.barisan.any((b) => b.tertinggal);
    final depan = kabar.barisan.first;

    return AnimatedContainer(
      duration: NapakMotion.sedang,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: adaTertinggal
            ? NapakColors.attention.withValues(alpha: 0.10)
            : NapakColors.softSky.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                adaTertinggal
                    ? Icons.warning_amber_rounded
                    : Icons.route_rounded,
                size: 18,
                color: adaTertinggal
                    ? NapakColors.attention
                    : NapakColors.deepAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  adaTertinggal
                      ? 'Ada yang tertinggal'
                      : 'Rombongan rapat',
                  style: text.titleSmall,
                ),
              ),
              Text(
                'rentang ${_jarak(kabar.rentangM)}',
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: LayoutBuilder(
              builder: (context, batas) =>
                  _Jalan(kabar: kabar, lebar: batas.maxWidth),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              '${depan.nama.split(' ').first} paling depan',
              for (final b in kabar.barisan.skip(1))
                b.hilangKontak
                    ? '${b.nama.split(' ').first} belum terdengar kabarnya'
                    : '${b.nama.split(' ').first} ${_jarak(b.selisihM)} di belakang',
            ].join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    ).animate().fadeIn(duration: NapakMotion.sedang).slideY(begin: -0.1);
  }
}

class _Jalan extends StatefulWidget {
  const _Jalan({required this.kabar, required this.lebar});

  final KabarKonvoi kabar;
  final double lebar;

  @override
  State<_Jalan> createState() => _JalanState();
}

class _JalanState extends State<_Jalan> with SingleTickerProviderStateMixin {
  late final AnimationController _marka = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _marka.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ukuran = 36.0;
    final rentang = math.max(widget.kabar.rentangM, 1);
    final ruang = widget.lebar - ukuran;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Aspal dan marka yang bergulir.
        Positioned(
          left: 0,
          right: 0,
          top: 26,
          height: 12,
          child: AnimatedBuilder(
            animation: _marka,
            builder: (context, _) => CustomPaint(
              painter: _PelukisJalan(geser: _marka.value),
            ),
          ),
        ),
        for (final b in widget.kabar.barisan)
          AnimatedPositioned(
            key: ValueKey(b.userId),
            duration: const Duration(milliseconds: 900),
            curve: NapakMotion.mengalir,
            // Yang terdepan di kanan; selisih terbesar di paling kiri.
            left: ruang * (1 - b.selisihM / rentang),
            top: 14,
            child: _Penanda(b: b, ukuran: ukuran),
          ),
      ],
    );
  }
}

class _Penanda extends StatelessWidget {
  const _Penanda({required this.b, required this.ukuran});

  final BarisKonvoi b;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    Widget lingkaran = Opacity(
      opacity: b.hilangKontak ? 0.45 : 1,
      child: LingkaranNama(nama: b.nama, ukuran: ukuran, cincin: b.urutan == 1),
    );

    if (b.tertinggal) {
      // Cincin berdenyut untuk yang tertinggal — terlihat dari sudut mata
      // tanpa harus membaca apa pun, karena yang melihat sedang menyetir.
      lingkaran = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
                width: ukuran,
                height: ukuran,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: NapakColors.attention, width: 2),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(end: 1.7, duration: 1200.ms, curve: Curves.easeOut)
              .fadeOut(duration: 1200.ms),
          lingkaran,
        ],
      );
    }

    return Tooltip(message: b.nama, child: lingkaran);
  }
}

class _PelukisJalan extends CustomPainter {
  _PelukisJalan({required this.geser});

  final double geser;

  @override
  void paint(Canvas canvas, Size size) {
    final aspal = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.drawRRect(aspal, Paint()..color = NapakColors.textPrimary.withValues(alpha: 0.12));

    // Marka putus-putus bergerak ke kiri: rombongan melaju ke kanan.
    const panjang = 14.0;
    const jarak = 12.0;
    const langkah = panjang + jarak;
    final marka = Paint()
      ..color = NapakColors.base
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = -langkah + (1 - geser) * langkah; x < size.width; x += langkah) {
      canvas.drawLine(
        Offset(math.max(0, x), y),
        Offset(math.min(size.width, x + panjang), y),
        marka,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisJalan lama) => lama.geser != geser;
}
