import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../../core/widgets/tourvella_skeleton.dart';
import '../../profil/presentation/profil_page.dart' show FotoProfil;
import '../../trips/presentation/pratinjau_rute.dart';
import '../data/linimasa_data.dart';

/// Linimasa di beranda: perjalanan yang dipajang teman, dan milikmu sendiri.
///
/// "Memposting" di Tourvella berarti memajang perjalanan di profil. Tidak ada
/// tombol posting terpisah — satu saklar, satu arti, jadi tidak ada yang
/// terbagikan tanpa sengaja.
class SliverLinimasa extends ConsumerWidget {
  const SliverLinimasa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linimasa = ref.watch(linimasaProvider);

    return linimasa.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              TourvellaSkeleton(tinggi: 360, radius: 18),
              SizedBox(height: 18),
              TourvellaSkeleton(tinggi: 360, radius: 18),
            ],
          ),
        ),
      ),
      error: (galat, _) => SliverToBoxAdapter(
        child: _Kosong(
          judul: 'Linimasanya belum bisa dibuka',
          isi: galat.toString(),
        ),
      ),
      data: (daftar) {
        if (daftar.isEmpty) {
          return const SliverToBoxAdapter(
            child: _Kosong(
              judul: 'Linimasa masih sepi',
              isi:
                  'Yang muncul di sini adalah perjalanan yang dipajang di '
                  'profil — milikmu dan teman-temanmu. Buka salah satu '
                  'perjalananmu, lalu nyalakan "Pajang di profil".',
            ),
          );
        }

        return SliverList.separated(
          itemCount: daftar.length,
          separatorBuilder: (_, _) => const SizedBox(height: 20),
          itemBuilder: (context, i) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              i == 0 ? 14 : 0,
              16,
              i == daftar.length - 1 ? 110 : 0,
            ),
            child: _KartuPost(post: daftar[i])
                .animate(delay: (60 * i.clamp(0, 5)).ms)
                .fadeIn(duration: TourvellaMotion.sedang)
                .slideY(begin: 0.06, curve: TourvellaMotion.mengalir),
          ),
        );
      },
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.judul, required this.isi});

  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 120),
      child: Column(
        children: [
          const JarumKompas(arah: 30, ukuran: 64),
          const SizedBox(height: 18),
          Text(judul, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            isi,
            style: text.bodyMedium?.copyWith(
              color: TourvellaColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _KartuPost extends ConsumerStatefulWidget {
  const _KartuPost({required this.post});

  final PostLinimasa post;

  @override
  ConsumerState<_KartuPost> createState() => _KartuPostState();
}

class _KartuPostState extends ConsumerState<_KartuPost> {
  late PostLinimasa _post = widget.post;
  int _halaman = 0;
  bool _mengirim = false;

  @override
  void didUpdateWidget(covariant _KartuPost lama) {
    super.didUpdateWidget(lama);
    if (lama.post != widget.post) _post = widget.post;
  }

  Future<void> _salut() async {
    if (_mengirim) return;
    final beri = !_post.sudahSalut;
    HapticFeedback.lightImpact();

    // Langsung berubah di layar; server menyusul. Salut yang menunggu
    // jaringan dulu terasa seperti tombol yang rusak.
    final sebelum = _post;
    setState(() {
      _mengirim = true;
      _post = _post.denganSalut(_post.salut + (beri ? 1 : -1), beri);
    });
    try {
      final hasil = await ref
          .read(linimasaRepositoryProvider)
          .salut(_post.tripId, beri: beri);
      if (mounted) {
        setState(() => _post = _post.denganSalut(hasil.salut, hasil.sudah));
      }
    } catch (_) {
      if (mounted) setState(() => _post = sebelum);
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _post;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: TourvellaColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Penulis ---
          TourvellaPressable(
            skala: 0.99,
            onTap: p.milikSendiri
                ? () => context.go('/profil')
                : () => context.push('/orang/${p.penulis.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  FotoProfil(
                    nama: p.penulis.nama,
                    url: p.penulis.fotoUrl,
                    ukuran: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.milikSendiri
                              ? '${p.penulis.nama} (kamu)'
                              : p.penulis.nama,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(_kapan(p.selesai), style: text.bodySmall),
                      ],
                    ),
                  ),
                  if (p.kendaraanNama != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TourvellaColors.warmNeutral,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            p.kendaraanJenis?.ikon ?? Icons.two_wheeler_rounded,
                            size: 14,
                            color: TourvellaColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              p.kendaraanNama!,
                              style: text.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // --- Media & bentuk rute ---
          TourvellaPressable(
            skala: 0.99,
            onTap: () => context.push('/trip/${p.tripId}'),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (p.media.isEmpty)
                    _LatarRute(post: p)
                  else
                    PageView.builder(
                      itemCount: p.media.length,
                      onPageChanged: (i) => setState(() => _halaman = i),
                      itemBuilder: (context, i) => Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            p.media[i].url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _LatarRute(post: p),
                          ),
                          if (p.media[i].video)
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                size: 56,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Kerudung bawah dan bentuk rute putih di atas foto — foto
                  // bercerita soal tempat, garisnya soal perjalanannya.
                  if (p.media.isNotEmpty)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              TourvellaColors.malam.withValues(alpha: 0.75),
                            ],
                            stops: const [0.5, 1],
                          ),
                        ),
                      ),
                    ),
                  if (p.media.isNotEmpty && p.previewPath.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      width: 96,
                      height: 96,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: TourvellaColors.malam.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PratinjauRute(
                            titik: p.previewPath,
                            tinggi: 96,
                            latar: Colors.transparent,
                            warna: TourvellaColors.base,
                          ),
                        ),
                      ),
                    ),
                  if (p.media.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TourvellaColors.malam.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_halaman + 1}/${p.media.length}',
                          style: text.labelSmall?.copyWith(
                            color: TourvellaColors.base,
                          ),
                        ),
                      ),
                    ),
                  if (p.media.isNotEmpty)
                    Positioned(
                      left: 14,
                      right: 120,
                      bottom: 14,
                      child: _Keterangan(post: p, gelap: true),
                    ),
                ],
              ),
            ),
          ),

          if (p.media.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _Keterangan(post: p, gelap: false),
            ),

          // --- Salut & buka ---
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
            child: Row(
              children: [
                _TombolSalut(
                  sudah: p.sudahSalut,
                  jumlah: p.salut,
                  onTap: p.milikSendiri && p.salut == 0 ? null : _salut,
                  milikSendiri: p.milikSendiri,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push('/trip/${p.tripId}'),
                  icon: const Icon(Icons.route_rounded, size: 18),
                  label: const Text('Lihat jejaknya'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _kapan(DateTime t) {
    final beda = DateTime.now().difference(t);
    if (beda.inMinutes < 60) return 'baru saja sampai';
    if (beda.inHours < 24) return 'sampai ${beda.inHours} jam lalu';
    if (beda.inDays < 7) return 'sampai ${beda.inDays} hari lalu';
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return 'sampai ${t.day} ${bulan[t.month - 1]} ${t.year}';
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({required this.post, required this.gelap});

  final PostLinimasa post;
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final warna = gelap ? TourvellaColors.base : TourvellaColors.textPrimary;
    final rute = [
      ?post.dari,
      if (post.ke != null && post.ke != post.dari) post.ke!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rute.isNotEmpty)
          LabelKapital(
            rute.join('  →  '),
            warna: gelap
                ? TourvellaColors.emberRedup
                : TourvellaColors.deepAccent,
            ukuran: 10,
          ),
        const SizedBox(height: 2),
        Text(
          post.judul,
          style: text.titleMedium?.copyWith(
            color: warna,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Odometer(
          nilai: post.km,
          desimal: post.km < 100 ? 1 : 0,
          satuan: 'KM',
          gaya: text.titleMedium?.copyWith(
            color: TourvellaColors.ember,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Perjalanan tanpa foto tetap punya wajah: bentuk rutenya di atas peta
/// kontur malam, jadi linimasanya tidak berlubang.
class _LatarRute extends StatelessWidget {
  const _LatarRute({required this.post});

  final PostLinimasa post;

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
        const IgnorePointer(child: KonturTopografi(opasitas: 0.3, benih: 37)),
        if (post.previewPath.length > 1)
          Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, batas) => PratinjauRute(
                titik: post.previewPath,
                tinggi: batas.maxHeight,
                latar: Colors.transparent,
                warna: TourvellaColors.ember,
              ),
            ),
          ),
      ],
    );
  }
}

class _TombolSalut extends StatelessWidget {
  const _TombolSalut({
    required this.sudah,
    required this.jumlah,
    required this.onTap,
    required this.milikSendiri,
  });

  final bool sudah;
  final int jumlah;
  final VoidCallback? onTap;
  final bool milikSendiri;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final warna = sudah ? TourvellaColors.ember : TourvellaColors.textSecondary;

    return TourvellaPressable(
      skala: 0.9,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikonnya melompat saat salut diberikan — kecil, sekali, cukup.
            AnimatedScale(
              scale: sudah ? 1.15 : 1,
              duration: TourvellaMotion.sedang,
              curve: TourvellaMotion.memantul,
              child: Icon(
                sudah ? Icons.front_hand_rounded : Icons.front_hand_outlined,
                color: warna,
                size: 22,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: TourvellaMotion.cepat,
              transitionBuilder: (anak, a) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(a),
                child: FadeTransition(opacity: a, child: anak),
              ),
              child: Text(
                jumlah == 0
                    ? (milikSendiri ? 'Belum ada salut' : 'Salut')
                    : '$jumlah salut',
                key: ValueKey('$jumlah-$sudah'),
                style: text.labelLarge?.copyWith(
                  color: warna,
                  fontWeight: sudah ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
