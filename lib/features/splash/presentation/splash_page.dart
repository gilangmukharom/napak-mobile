import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/theme/napak_tekstur.dart';
import '../../../core/widgets/napak_ekspedisi.dart';
import '../../../core/widgets/napak_gerak.dart';

/// Layar pembuka.
///
/// Bukan sekadar pengisi waktu. Selagi ini berjalan, aplikasi memang sedang
/// bekerja: membuka Keystore, membaca token, menanyakan sesinya masih sah
/// atau tidak. Yang ditampilkan bukan kebohongan.
///
/// Yang digambar adalah sepotong jejak yang menggambar dirinya sendiri —
/// bukan logo. Merek Napak memang bukan lambang, melainkan garis perjalanan,
/// dan animasi ini mengatakan itu sebelum satu kata pun terbaca.
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
    duration: NapakMotion.pembuka,
  );

  late final Animation<double> _jejak = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.0, 0.72, curve: Curves.easeInOutCubic),
  );

  late final Animation<double> _nama = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.38, 0.86, curve: NapakMotion.mengalir),
  );

  late final Animation<double> _kalimat = CurvedAnimation(
    parent: _kendali,
    curve: const Interval(0.58, 1.0, curve: NapakMotion.mengalir),
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
      backgroundColor: NapakColors.malam,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: NapakColors.langitSubuh,
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
                NapakColors.malamNaik,
                NapakColors.malam,
              ],
            ),
          ),
          const ButiranKertas(opasitas: 0.05),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _jejak,
                      builder: (context, _) => JejakMenggambar(
                        progres: _jejak.value,
                        // Jejak digambar dengan bara, bukan biru: di atas
                        // langit malam, birunya hilang ditelan latar.
                        gradasi: const [
                          NapakColors.ember,
                          NapakColors.emberRedup,
                        ],
                        tebal: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Memudar(
                    animasi: _nama,
                    child: Text(
                      'Napak',
                      style: text.displaySmall?.copyWith(
                        color: NapakColors.base,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Memudar(
                    animasi: _kalimat,
                    child: Text(
                      'Setiap perjalanan meninggalkan jejak.',
                      style: text.bodyLarge?.copyWith(
                        color: NapakColors.base.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
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
                  'Napak tilas · Indonesia',
                  warna: NapakColors.base.withValues(alpha: 0.4),
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
