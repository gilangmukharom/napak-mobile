import 'package:flutter/material.dart';

import '../theme/napak_colors.dart';
import '../theme/napak_motion.dart';

/// Kerangka yang berkilau pelan selagi isinya dimuat.
///
/// Menggantikan lingkaran berputar. Bedanya bukan sekadar gaya: kerangka
/// memberi tahu bentuk apa yang sedang datang, jadi mata sudah siap dan
/// halamannya tidak terasa melompat saat isinya masuk. Lingkaran berputar
/// tidak memberi tahu apa-apa selain "tunggu".
///
/// Kilaunya sengaja lambat dan tipis — ini latar yang sedang menunggu, bukan
/// sesuatu yang minta diperhatikan.
class NapakSkeleton extends StatefulWidget {
  const NapakSkeleton({
    required this.tinggi,
    this.lebar = double.infinity,
    this.radius = 12,
    this.gelap = false,
    super.key,
  });

  /// Kerangka berbentuk baris teks.
  const NapakSkeleton.teks({this.lebar = 160, this.gelap = false, super.key})
    : tinggi = 13,
      radius = 6;

  final double tinggi;
  final double lebar;
  final double radius;

  /// Dipakai di atas kanvas malam. Kerangka terang di sana terbaca seperti
  /// balok putih menyala, bukan seperti isi yang sedang datang.
  final bool gelap;

  @override
  State<NapakSkeleton> createState() => _NapakSkeletonState();
}

class _NapakSkeletonState extends State<NapakSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kendali,
      builder: (context, _) {
        // Kilau bergerak dari kiri ke kanan, dengan jeda diam di ujungnya
        // supaya tidak terasa seperti lampu disko.
        final posisi = _kendali.value * 2.5 - 0.75;

        return Container(
          height: widget.tinggi,
          width: widget.lebar,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(posisi - 0.6, 0),
              end: Alignment(posisi + 0.6, 0),
              colors: widget.gelap
                  ? const [
                      NapakColors.malamNaik,
                      NapakColors.kontur,
                      NapakColors.malamNaik,
                    ]
                  : const [
                      NapakColors.softSky,
                      NapakColors.base,
                      NapakColors.softSky,
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Kerangka satu kartu perjalanan, sebentuk dengan kartu aslinya.
class SkeletonKartuTrip extends StatelessWidget {
  const SkeletonKartuTrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NapakSkeleton(tinggi: 160, radius: 0),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NapakSkeleton.teks(lebar: 180),
                SizedBox(height: 10),
                NapakSkeleton.teks(lebar: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar kerangka yang muncul bertahap, sama seperti daftar aslinya nanti.
class SkeletonDaftarTrip extends StatelessWidget {
  const SkeletonDaftarTrip({this.jumlah = 3, super.key});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < jumlah; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: NapakMotion.sedang,
              curve: NapakMotion.mengalir,
              builder: (context, t, anak) =>
                  Opacity(opacity: t * (1 - i * 0.22), child: anak),
              child: const SkeletonKartuTrip(),
            ),
          ),
      ],
    );
  }
}
