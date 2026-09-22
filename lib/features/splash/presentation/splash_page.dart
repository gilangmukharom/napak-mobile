import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_logo.dart';

/// Layar pembuka.
///
/// Bukan sekadar pengisi waktu. Selagi ini berjalan, aplikasi memang sedang
/// bekerja: membuka Keystore, membaca token, menanyakan sesinya masih sah
/// atau tidak. Yang ditampilkan bukan kebohongan.
///
/// Yang digambar adalah tanda Tourvella yang menyusun dirinya sendiri: jalan
/// tumbuh dari bawah layar, horizon membentang, lalu matahari tujuan terbit.
/// Logonya memang sebuah perjalanan kecil, dan animasi ini mengatakan itu
/// sebelum satu kata pun terbaca. Warna latarnya sama dengan layar native
/// sebelum Flutter hidup (`flutter_native_splash`), jadi tidak ada kedipan.
///
/// Durasinya ditahan sampai animasinya tuntas walau sesi sudah ketahuan lebih
/// dulu. Layar pembuka yang berkedip sepersekian detik lalu hilang terasa
/// seperti gangguan, bukan sambutan.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: TourvellaMotion.pembuka,
  );

  /// Logo punya kurvanya sendiri per bagian; di sini cukup linear.
  late final Animation<double> _logo = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.0, 0.7),
  );

  late final Animation<double> _nama = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.5, 0.88, curve: TourvellaMotion.mengalir),
  );

  late final Animation<double> _kalimat = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.66, 1.0, curve: TourvellaMotion.mengalir),
  );

  bool _sudahPindah = false;

  @override
  void initState() {
    super.initState();

    // Listener dipasang sekali di sini, bukan di build(). Kalau di build(),
    // tiap rebuild menambah satu listener lagi dan mereka menumpuk diam-diam.
    _kendali.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pindahKalauSiap(ref.read(sessionProvider).value);
      }
    });

    _kendali.forward();
  }

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  /// Pindah hanya setelah dua hal terpenuhi: animasinya tuntas, dan sesinya
  /// sudah ketahuan. Mana pun yang selesai belakangan, itu yang ditunggu.
  void _pindahKalauSiap(bool? punyaSesi) {
    if (_sudahPindah || punyaSesi == null) return;
    if (_kendali.status != AnimationStatus.completed) return;

    _sudahPindah = true;
    context.go(punyaSesi ? '/' : '/masuk');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    ref.listen(sessionProvider, (_, next) => _pindahKalauSiap(next.value));

    // Langit sebelum berangkat: gelap di atas, bara di kaki langit, dan
    // punggungan gunung yang naik perlahan seperti dilihat dari jok motor.
    return Scaffold(
      backgroundColor: TourvellaColors.malam,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: TourvellaColors.langitSubuh,
                stops: [0, 0.6, 1.25],
              ),
            ),
          ),
          const IgnorePointer(child: KonturTopografi(opasitas: 0.16)),

          // Gunung naik pelan sepanjang pembukaan.
          AnimatedBuilder(
            animation: _kendali,
            builder: (context, _) => SiluetGunung(
              geser: 42 * (1 - Curves.easeOutCubic.transform(_kendali.value)),
              warna: const [
                Color(0xFF2E3B4E),
                TourvellaColors.malamNaik,
                TourvellaColors.malam,
              ],
            ),
          ),
          const ButiranKertas(opasitas: 0.05),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logo,
                  builder: (context, _) =>
                      LogoTourvella(ukuran: 148, progres: _logo.value),
                ),
                const SizedBox(height: 22),
                _Memudar(
                  animasi: _nama,
                  child: Text(
                    'Tourvella',
                    style: text.displaySmall?.copyWith(
                      color: TourvellaColors.base,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Memudar(
                  animasi: _kalimat,
                  child: Text(
                    'Setiap perjalanan punya cerita.',
                    style: text.bodyLarge?.copyWith(
                      color: TourvellaColors.base.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Center(
              child: _Memudar(
                animasi: _kalimat,
                child: LabelKapital(
                  'Rekam jalanmu · bagikan ceritamu',
                  warna: TourvellaColors.base.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muncul sambil naik sedikit. Cukup halus untuk tidak menarik perhatian
/// ke animasinya sendiri.
class _Memudar extends StatelessWidget {
  const _Memudar({required this.animasi, required this.child});

  final Animation<double> animasi;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animasi,
      builder: (context, anak) => Opacity(
        opacity: animasi.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animasi.value) * 16),
          child: anak,
        ),
      ),
      child: child,
    );
  }
}
