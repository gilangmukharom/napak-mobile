import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../../core/widgets/tourvella_skeleton.dart';
import '../../recording/application/recording_controller.dart';
import '../../trips/data/trip_models.dart';
import '../application/live_location_controller.dart';

/// Tab Trip Bareng.
///
/// Perjalanan rombongan dipisahkan dari beranda karena sifatnya beda: yang
/// satu arsip pribadi, yang satu ruang bersama yang masih berjalan. Menumpuk
/// keduanya di satu daftar membuat undangan dari teman tenggelam di antara
/// perjalanan lama.
class BarengPage extends ConsumerWidget {
  const BarengPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      body: RefreshIndicator(
        color: TourvellaColors.deepAccent,
        backgroundColor: Colors.white,
        onRefresh: () async => ref.invalidate(tripListProvider),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _KepalaBareng()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                child: _KartuGabung(onTap: () => _gabung(context, ref)),
              ),
            ),

            trips.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SkeletonDaftarTrip(jumlah: 2),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _Kosong(
                  ikon: Icons.cloud_off_rounded,
                  judul: 'Belum tersambung',
                  keterangan: error.toString(),
                ),
              ),
              data: (semua) {
                final bareng = semua
                    .where((t) => t.mode == TripMode.group)
                    .toList();

                if (bareng.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _Kosong(
                      ikon: Icons.group_outlined,
                      judul: 'Belum ada perjalanan bareng',
                      keterangan:
                          'Mulai perjalanan dengan mode Bareng, lalu bagikan '
                          'kodenya. Rute tiap orang akan tergambar dengan '
                          'warnanya sendiri di satu peta.',
                    ),
                  );
                }

                return SliverList.separated(
                  itemCount: bareng.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      i == 0 ? 8 : 0,
                      24,
                      i == bareng.length - 1 ? 110 : 0,
                    ),
                    child: MunculBertahap(
                      indeks: i,
                      child: _KartuBareng(trip: bareng[i]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gabung(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final gabung = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(sheetContext).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan kode undangan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Minta kodenya ke yang memimpin perjalanan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Kode undangan'),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('Gabung'),
            ),
          ],
        ),
      ),
    );

    if (gabung != true || controller.text.trim().isEmpty) return;

    try {
      final anggota = await ref
          .read(tripRepositoryProvider)
          .joinBySlug(controller.text.trim());
      ref.invalidate(tripListProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kamu bergabung sebagai ${anggota.name}. Selamat jalan bareng.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

/// Kepala tab Bareng: kanvas malam, punggungan, dan satu kompas.
///
/// Kompasnya bukan hiasan yang berputar asal. Jarumnya bergoyang pelan
/// seperti kompas sungguhan di atas tangki motor — cukup untuk memberi tahu
/// bahwa halaman ini soal berangkat bersama, bukan soal arsip.
class _KepalaBareng extends StatelessWidget {
  const _KepalaBareng();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: TourvellaColors.langitSubuh,
          stops: [0, 0.6, 1.5],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.18, benih: 13),
            ),
          ),
          const Positioned.fill(
            child: SiluetGunung(
              warna: [TourvellaColors.malamNaik, TourvellaColors.malam],
            ),
          ),
          const Positioned.fill(child: ButiranKertas(opasitas: 0.04)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LabelKapital(
                          'Rombongan',
                          warna: TourvellaColors.emberRedup,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jalan bareng',
                          style: text.displaySmall?.copyWith(
                            color: TourvellaColors.base,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Perjalanan yang kamu tempuh bersama orang lain.',
                          style: text.bodyMedium?.copyWith(
                            color: TourvellaColors.base.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const JarumKompas(arah: -18, ukuran: 62),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuGabung extends StatelessWidget {
  const _KartuGabung({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return TourvellaPressable(
      onTap: onTap,
      skala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TourvellaColors.warmNeutral,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TourvellaColors.ember.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: TourvellaColors.ember.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.group_add_outlined,
                size: 21,
                color: TourvellaColors.ember,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gabung perjalanan teman',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const LabelKapital('Pakai kode undangan', ukuran: 10),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: TourvellaColors.ember,
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuBareng extends ConsumerWidget {
  const _KartuBareng({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return TourvellaPressable(
      onTap: () => context.push('/trip/${trip.id}/bareng'),
      skala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: TourvellaColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(trip.title, style: text.titleLarge)),
                if (trip.isRecording)
                  const TitikBerdenyut(
                    warna: TourvellaColors.deepAccent,
                    ukuran: 7,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              trip.startedAt == null
                  ? 'Belum berangkat'
                  : DateFormat("d MMMM yyyy", 'id_ID').format(trip.startedAt!),
              style: text.bodySmall,
            ),
            const SizedBox(height: 18),
            _GarisAnggota(tripId: trip.id),
            const SizedBox(height: 16),
            Row(
              children: [
                _Keping(
                  ikon: Icons.straighten_rounded,
                  teks: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 18),
                _Keping(
                  ikon: Icons.timeline_rounded,
                  teks: '${trip.pointCount} jejak',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Deretan warna anggota — sekilas langsung kelihatan berapa orang di dalamnya.
class _GarisAnggota extends ConsumerWidget {
  const _GarisAnggota({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anggota = ref.watch(memberListProvider(tripId));
    final text = Theme.of(context).textTheme;

    return anggota.when(
      loading: () =>
          const TourvellaSkeleton(tinggi: 22, lebar: 140, radius: 11),
      error: (_, _) => const SizedBox.shrink(),
      data: (daftar) {
        if (daftar.isEmpty) return const SizedBox.shrink();

        return Row(
          children: [
            for (final m in daftar.take(5))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  height: 22,
                  width: 6,
                  decoration: BoxDecoration(
                    color: _hexKeColor(m.routeColor),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              daftar.length == 1
                  ? 'Baru kamu'
                  : '${daftar.length} orang jalan bareng',
              style: text.bodySmall,
            ),
          ],
        );
      },
    );
  }

  static Color _hexKeColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
}

class _Keping extends StatelessWidget {
  const _Keping({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 15, color: TourvellaColors.deepAccent),
        const SizedBox(width: 6),
        Text(teks, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: TourvellaMotion.lambat,
            curve: TourvellaMotion.memantul,
            builder: (context, t, anak) =>
                Transform.scale(scale: t, child: anak),
            child: Icon(ikon, size: 42, color: TourvellaColors.primary),
          ),
          const SizedBox(height: 20),
          Text(judul, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(keterangan, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
