import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../../core/widgets/tourvella_skeleton.dart';
import '../data/garasi_data.dart';
import 'edit_kendaraan_page.dart';

/// Garasi di halaman profil: kisi dua kolom kendaraan.
///
/// Terpisah dari kisi foto perjalanan, karena yang dipamerkan beda: foto
/// perjalanan bercerita soal tempat, garasi bercerita soal teman seperjalanan
/// yang tidak bisa bicara — dan kilometernya yang ditempuh bersama.
class SliverGarasi extends ConsumerWidget {
  const SliverGarasi({
    required this.pemilikId,
    required this.diriSendiri,
    super.key,
  });

  final String pemilikId;
  final bool diriSendiri;

  String get _kunci => diriSendiri ? 'saya' : pemilikId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garasi = ref.watch(garasiProvider(_kunci));

    return garasi.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(child: TourvellaSkeleton(tinggi: 210, radius: 16)),
              SizedBox(width: 12),
              Expanded(child: TourvellaSkeleton(tinggi: 210, radius: 16)),
            ],
          ),
        ),
      ),
      error: (galat, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            galat.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      data: (daftar) {
        if (daftar.isEmpty && !diriSendiri) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.garage_outlined,
                    size: 40,
                    color: TourvellaColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Garasinya masih kosong.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          );
        }

        final isi = [
          for (final k in daftar) _KartuKendaraan(k: k, pemilikKunci: _kunci),
          if (diriSendiri) _KartuTambah(pemilikKunci: _kunci),
        ];

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemCount: isi.length,
            itemBuilder: (context, i) => isi[i]
                .animate(delay: (70 * i).ms)
                .fadeIn(duration: TourvellaMotion.sedang)
                .slideY(begin: 0.12, curve: TourvellaMotion.mengalir),
          ),
        );
      },
    );
  }
}

class _KartuKendaraan extends ConsumerWidget {
  const _KartuKendaraan({required this.k, required this.pemilikKunci});

  final Kendaraan k;
  final String pemilikKunci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return TourvellaPressable(
      skala: 0.97,
      onTap: () => _bukaDetail(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: TourvellaColors.malam,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (k.fotoUrl != null)
              Hero(
                tag: 'kendaraan-${k.id}',
                child: Image.network(
                  k.fotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _LatarTanpaFoto(jenis: k.jenis),
                ),
              )
            else
              _LatarTanpaFoto(jenis: k.jenis),

            // Kerudung bawah: nama dan angka putih harus terbaca di atas
            // foto jok kulit hitam maupun cat putih mengilap.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    TourvellaColors.malam.withValues(alpha: 0.2),
                    TourvellaColors.malam.withValues(alpha: 0.92),
                  ],
                  stops: const [0.35, 0.55, 1],
                ),
              ),
            ),

            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TourvellaColors.malam.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      k.jenis.ikon,
                      size: 14,
                      color: TourvellaColors.emberRedup,
                    ),
                    const SizedBox(width: 4),
                    LabelKapital(
                      k.jenis.label,
                      warna: TourvellaColors.emberRedup,
                      ukuran: 9,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.nama,
                    style: text.titleMedium?.copyWith(
                      color: TourvellaColors.base,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (k.merekModel != null || k.tahun != null)
                    Text(
                      [
                        ?k.merekModel,
                        if (k.tahun != null) '${k.tahun}',
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Odometer(
                    nilai: k.km,
                    desimal: k.km < 100 ? 1 : 0,
                    satuan: 'KM',
                    gaya: text.titleMedium?.copyWith(
                      color: TourvellaColors.ember,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bukaDetail(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TourvellaColors.malam,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _DetailKendaraan(k: k, pemilikKunci: pemilikKunci),
    );
  }
}

class _LatarTanpaFoto extends StatelessWidget {
  const _LatarTanpaFoto({required this.jenis});

  final JenisKendaraan jenis;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: TourvellaColors.kanvasMalam,
            ),
          ),
        ),
        const IgnorePointer(
          child: KonturTopografi(opasitas: 0.28, jumlahGaris: 5, benih: 41),
        ),
        Align(
          alignment: const Alignment(0, -0.2),
          child: Icon(
            jenis.ikon,
            size: 56,
            color: TourvellaColors.base.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

/// Tambah kendaraan — kartu berbingkai putus-putus, seperti petak parkir
/// yang masih kosong.
class _KartuTambah extends ConsumerWidget {
  const _KartuTambah({required this.pemilikKunci});

  final String pemilikKunci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TourvellaPressable(
      skala: 0.97,
      onTap: () async {
        final ada = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const EditKendaraanPage()),
        );
        if (ada == true) ref.invalidate(garasiProvider(pemilikKunci));
      },
      child: CustomPaint(
        painter: _BingkaiPutus(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TourvellaColors.ember.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: TourvellaColors.ember,
                ),
              ),
              const SizedBox(height: 10),
              const LabelKapital('Tambah kendaraan', ukuran: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _BingkaiPutus extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(16),
    );
    final jalur = Path()..addRRect(rrect);
    final cat = Paint()
      ..color = TourvellaColors.kontur.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final m in jalur.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), cat);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DetailKendaraan extends ConsumerWidget {
  const _DetailKendaraan({required this.k, required this.pemilikKunci});

  final Kendaraan k;
  final String pemilikKunci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: k.fotoUrl != null
                  ? Hero(
                      tag: 'kendaraan-${k.id}',
                      child: Image.network(k.fotoUrl!, fit: BoxFit.cover),
                    )
                  : _LatarTanpaFoto(jenis: k.jenis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelKapital(
                    [
                      k.jenis.label,
                      ?k.merekModel,
                      if (k.tahun != null) '${k.tahun}',
                    ].join(' · '),
                    warna: TourvellaColors.emberRedup,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    k.nama,
                    style: text.headlineSmall?.copyWith(
                      color: TourvellaColors.base,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Odometer(
                        nilai: k.km,
                        desimal: k.km < 100 ? 1 : 0,
                        satuan: 'KM BERSAMA',
                        gaya: text.headlineMedium?.copyWith(
                          color: TourvellaColors.ember,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      LabelKapital(
                        '${k.perjalanan} perjalanan',
                        warna: TourvellaColors.base.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  if (k.cerita != null) ...[
                    const SizedBox(height: 16),
                    const PemisahJalur(warna: TourvellaColors.kontur),
                    const SizedBox(height: 14),
                    Text(
                      k.cerita!,
                      style: text.bodyLarge?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (k.milikSendiri) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TourvellaColors.base,
                              side: const BorderSide(
                                color: TourvellaColors.kontur,
                              ),
                            ),
                            onPressed: () => _lepas(context, ref),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Lepas'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: TourvellaColors.ember,
                              foregroundColor: TourvellaColors.malam,
                            ),
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final ubah = await navigator.push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditKendaraanPage(awal: k),
                                ),
                              );
                              if (ubah == true) {
                                ref.invalidate(garasiProvider(pemilikKunci));
                                navigator.pop();
                              }
                            },
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Ubah'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lepas(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lepas ${k.nama} dari garasi?'),
        content: const Text(
          'Fotonya ikut dihapus. Perjalanan yang pernah ditempuh dengannya '
          'tetap utuh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (yakin != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    await ref.read(garasiRepositoryProvider).hapus(k.id);
    ref.invalidate(garasiProvider(pemilikKunci));
    navigator.pop();
  }
}
