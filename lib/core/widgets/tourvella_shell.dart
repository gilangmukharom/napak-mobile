import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/tourvella_colors.dart';
import '../theme/tourvella_motion.dart';
import '../theme/tourvella_tekstur.dart';
import '../../features/recording/application/recording_controller.dart';

import 'tourvella_pressable.dart';

/// Rangka utama aplikasi: isi halaman di atas, navigasi di bawah.
///
/// Bentuknya meminjam dari aplikasi yang tiap hari dipakai orang — tab di
/// bawah, tombol utama di tengah — karena ibu jari sudah hafal tempat itu.
/// Menaruh tombol "Mulai merekam" di pojok kanan atas berarti meminta orang
/// memindahkan genggaman di atas motor.
///
/// Yang diambil hanya mekanikanya. Bilahnya sendiri gelap seperti panel
/// instrumen: layar di atasnya boleh terang, tapi kemudi aplikasi ini duduk
/// di atas kanvas malam dengan satu titik bara sebagai penanda aktif.
class TourvellaShell extends ConsumerWidget {
  const TourvellaShell({required this.child, super.key});

  final Widget child;

  static const _tab = [
    (
      jalur: '/',
      ikon: Icons.route_outlined,
      aktif: Icons.route,
      label: 'Jejak',
    ),
    (
      jalur: '/bareng',
      ikon: Icons.group_outlined,
      aktif: Icons.group,
      label: 'Bareng',
    ),
    (
      jalur: '/recap',
      ikon: Icons.auto_awesome_outlined,
      aktif: Icons.auto_awesome,
      label: 'Recap',
    ),
    (
      jalur: '/profil',
      ikon: Icons.person_outline_rounded,
      aktif: Icons.person_rounded,
      label: 'Kamu',
    ),
  ];

  static int indeksDari(String lokasi) {
    // Dicocokkan dari yang terpanjang supaya '/bareng' tidak kalah oleh '/'.
    for (var i = _tab.length - 1; i > 0; i--) {
      if (lokasi.startsWith(_tab[i].jalur)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lokasi = GoRouterState.of(context).uri.path;
    final terpilih = indeksDari(lokasi);
    final merekam = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _BilahBawah(
        terpilih: terpilih,
        tab: _tab,
        merekam: merekam,
      ),
    );
  }
}

typedef _Tab = ({String jalur, IconData ikon, IconData aktif, String label});

class _BilahBawah extends StatelessWidget {
  const _BilahBawah({
    required this.terpilih,
    required this.tab,
    required this.merekam,
  });

  final int terpilih;
  final List<_Tab> tab;
  final bool merekam;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TourvellaColors.malam,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: TourvellaColors.kontur)),
        boxShadow: [
          BoxShadow(
            color: TourvellaColors.malam.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Kontur tipis di balik bilah: bahkan panel kemudinya pun peta.
          const Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.16, jumlahGaris: 3, benih: 21),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _TombolTab(tab: tab[0], terpilih: terpilih == 0),
                  _TombolTab(tab: tab[1], terpilih: terpilih == 1),
                  _TombolRekam(merekam: merekam),
                  _TombolTab(tab: tab[2], terpilih: terpilih == 2),
                  _TombolTab(tab: tab[3], terpilih: terpilih == 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TombolTab extends StatelessWidget {
  const _TombolTab({required this.tab, required this.terpilih});

  final _Tab tab;
  final bool terpilih;

  @override
  Widget build(BuildContext context) {
    final warna = terpilih
        ? TourvellaColors.ember
        : TourvellaColors.base.withValues(alpha: 0.55);

    return Expanded(
      child: TourvellaPressable(
        skala: 0.9,
        onTap: () => context.go(tab.jalur),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon naik sedikit dan berganti jadi versi terisi saat aktif —
            // dua isyarat sekaligus, jadi tetap terbaca tanpa bergantung warna.
            AnimatedSlide(
              offset: Offset(0, terpilih ? -0.08 : 0),
              duration: TourvellaMotion.cepat,
              curve: TourvellaMotion.memantul,
              child: Icon(
                terpilih ? tab.aktif : tab.ikon,
                size: 23,
                color: warna,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: TourvellaMotion.cepat,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: warna,
                fontWeight: terpilih ? FontWeight.w800 : FontWeight.w500,
                fontSize: 10,
                letterSpacing: terpilih ? 1.4 : 0.8,
              ),
              child: Text(tab.label.toUpperCase()),
            ),
            const SizedBox(height: 3),
            // Titik bara di bawah tab aktif: penanda posisi di peta, bukan
            // bilah tebal yang menekan tata letaknya.
            AnimatedContainer(
              duration: TourvellaMotion.sedang,
              curve: TourvellaMotion.memantul,
              height: 3,
              width: terpilih ? 14 : 0,
              decoration: BoxDecoration(
                color: TourvellaColors.ember,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol tengah. Satu-satunya yang berwarna bara penuh di bilah ini.
///
/// Saat sedang merekam, ia berubah jadi penanda berdenyut yang membawa
/// kembali ke perjalanan yang sedang berjalan — bukan tombol mulai lagi.
class _TombolRekam extends StatelessWidget {
  const _TombolRekam({required this.merekam});

  final bool merekam;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: TourvellaPressable(
          skala: 0.88,
          onTap: () => context.push(merekam ? '/rekam' : '/rekam/mulai'),
          child: AnimatedContainer(
            duration: TourvellaMotion.sedang,
            curve: TourvellaMotion.memantul,
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: merekam
                    ? const [TourvellaColors.emberRedup, TourvellaColors.ember]
                    : const [TourvellaColors.ember, Color(0xFFB96F38)],
              ),
              borderRadius: BorderRadius.circular(merekam ? 23 : 16),
              boxShadow: [
                BoxShadow(
                  color: TourvellaColors.ember.withValues(
                    alpha: merekam ? 0.55 : 0.32,
                  ),
                  blurRadius: merekam ? 22 : 14,
                  spreadRadius: merekam ? 2 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: merekam
                ? const _DenyutRekam()
                : const Icon(
                    Icons.add_rounded,
                    color: TourvellaColors.malam,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DenyutRekam extends StatefulWidget {
  const _DenyutRekam();

  @override
  State<_DenyutRekam> createState() => _DenyutRekamState();
}

class _DenyutRekamState extends State<_DenyutRekam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _kendali.drive(
          Tween(
            begin: 0.72,
            end: 1.0,
          ).chain(CurveTween(curve: TourvellaMotion.masukKeluar)),
        ),
        child: Container(
          height: 16,
          width: 16,
          decoration: const BoxDecoration(
            color: TourvellaColors.malam,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
