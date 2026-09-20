import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../../core/widgets/napak_skeleton.dart';
import '../../recording/application/recording_controller.dart';
import '../../render/presentation/video_sheet.dart';
import '../data/trip_models.dart';
import 'peta_rute.dart';

final _tripDetailProvider = FutureProvider.family<Trip, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).detail(tripId),
);

final _tripPointsProvider = FutureProvider.family<List<TripPoint>, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).points(tripId),
);

/// Halaman satu perjalanan.
///
/// Petanya mengisi seluruh bagian atas dan menyusut jadi bilah judul saat
/// digulir, jadi yang pertama dilihat memang jejaknya — bukan judul di atas
/// kotak kecil. Angka dan catatan datang setelahnya, sebagai keterangan atas
/// gambar itu.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  /// Perjalanan solo hanya punya satu jalur; Trip Bareng memecahnya per orang
  /// di layarnya sendiri.
  static const _jalurUtama = 'utama';

  final _petaController = PetaRuteController();

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(_tripDetailProvider(widget.tripId));
    final titik = ref.watch(_tripPointsProvider(widget.tripId));

    // Kalau perjalanan ini yang sedang direkam, titik baru ditempelkan ke
    // garis yang sudah ada — bukan dengan memuat ulang seluruh rute.
    ref.listen(
      recordingControllerProvider.select((s) => s.latest),
      (sebelum, sekarang) {
        final rekaman = ref.read(recordingControllerProvider);
        if (sekarang == null || rekaman.tripId != widget.tripId) return;
        _petaController.tambahTitik(
          _jalurUtama,
          LatLng(sekarang.lat, sekarang.lng),
        );
      },
    );

    return Scaffold(
      backgroundColor: NapakColors.base,
      body: trip.when(
        loading: () => const _MemuatDetail(),
        error: (error, _) => _Galat(pesan: error.toString()),
        data: (data) => CustomScrollView(
          slivers: [
            _KepalaPeta(
              trip: data,
              titik: titik,
              peta: _petaController,
              jalurId: _jalurUtama,
              onVisibility: () => _aturVisibility(context, data),
              onHapus: () => _hapus(context, data),
            ),
            SliverToBoxAdapter(child: _Ringkasan(trip: data)),
            SliverToBoxAdapter(child: _BarisAksi(trip: data)),
            titik.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NapakSkeleton.teks(lebar: 120),
                      SizedBox(height: 16),
                      NapakSkeleton(tinggi: 76, radius: 16),
                    ],
                  ),
                ),
              ),
              error: (error, _) =>
                  SliverToBoxAdapter(child: _Galat(pesan: error.toString())),
              data: (daftar) => _DaftarSinggahan(titik: daftar),
            ),
          ],
        ),
      ),
    );
  }

  IconData _ikonVisibility(TripVisibility v) => switch (v) {
    TripVisibility.private => Icons.lock_outline_rounded,
    TripVisibility.link => Icons.link_rounded,
    TripVisibility.public => Icons.public_rounded,
  };

  Future<void> _aturVisibility(BuildContext context, Trip trip) async {
    final pilihan = await showModalBottomSheet<TripVisibility>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text(
                'Siapa yang boleh melihat?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Orang di luar perjalanan ini hanya melihat bentuk rutenya '
                'secara kasar — bukan titik persisnya, dan tanpa catatanmu.',
                style: TextStyle(color: NapakColors.textSecondary, height: 1.5),
              ),
            ),
            for (final v in TripVisibility.values)
              ListTile(
                leading: Icon(_ikonVisibility(v), color: NapakColors.deepAccent),
                title: Text(v.label),
                trailing: trip.visibility == v
                    ? const Icon(
                        Icons.check_rounded,
                        color: NapakColors.deepAccent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(v),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (pilihan == null || pilihan == trip.visibility) return;

    await ref.read(tripRepositoryProvider).setVisibility(trip.id, pilihan);
    ref.invalidate(_tripDetailProvider(trip.id));
    ref.invalidate(tripListProvider);
  }

  Future<void> _hapus(BuildContext context, Trip trip) async {
    final controller = TextEditingController();

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NapakColors.base,
        title: const Text('Hapus perjalanan ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seluruh jejak, catatan, foto, dan video yang sudah dibuat '
              'dihapus sepenuhnya. Tidak disembunyikan — benar-benar hilang, '
              'dan tidak bisa dikembalikan.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
            Text(
              'Ketik ulang judulnya untuk memastikan:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: trip.title),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: NapakColors.attention,
            ),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    try {
      final pesan = await ref
          .read(tripRepositoryProvider)
          .deletePermanently(trip.id, controller.text);
      await ref.read(localDatabaseProvider).dropTrip(trip.id);
      ref.invalidate(tripListProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      context.go('/');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

/// Peta besar yang menyusut jadi bilah judul saat digulir.
class _KepalaPeta extends StatelessWidget {
  const _KepalaPeta({
    required this.trip,
    required this.titik,
    required this.peta,
    required this.jalurId,
    required this.onVisibility,
    required this.onHapus,
  });

  final Trip trip;
  final AsyncValue<List<TripPoint>> titik;
  final PetaRuteController peta;
  final String jalurId;
  final VoidCallback onVisibility;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: NapakColors.base,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 56,
      leading: const _TombolBulat(ikon: Icons.arrow_back_rounded),
      actions: [
        if (trip.isOwner)
          _TombolBulat(
            ikon: switch (trip.visibility) {
              TripVisibility.private => Icons.lock_outline_rounded,
              TripVisibility.link => Icons.link_rounded,
              TripVisibility.public => Icons.public_rounded,
            },
            onTap: onVisibility,
          ),
        if (trip.isOwner)
          _TombolBulat(
            ikon: Icons.delete_outline_rounded,
            warna: NapakColors.attention,
            onTap: onHapus,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: titik.when(
          loading: () => const PetaKosong(),
          error: (_, _) => const PetaKosong(),
          data: (daftar) => daftar.isEmpty
              ? const PetaKosong()
              // Peta muncul memudar, bukan berkedip masuk — tile-nya butuh
              // waktu, dan kedipan itu yang paling terasa murah.
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: NapakMotion.lambat,
                  curve: NapakMotion.mengalir,
                  builder: (context, t, anak) =>
                      Opacity(opacity: t, child: anak),
                  child: PetaRute(
                    controller: peta,
                    jalur: [
                      JalurRute(
                        id: jalurId,
                        titik: [for (final t in daftar) LatLng(t.lat, t.lng)],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Tombol bundar bertumpuk di atas peta, supaya ikonnya tetap terbaca
/// di atas warna apa pun.
class _TombolBulat extends StatelessWidget {
  const _TombolBulat({
    required this.ikon,
    this.onTap,
    this.warna = NapakColors.deepAccent,
  });

  final IconData ikon;
  final VoidCallback? onTap;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NapakPressable(
        skala: 0.88,
        onTap: onTap ?? () => context.pop(),
        child: Container(
          height: 36,
          width: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: NapakColors.base.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(ikon, size: 19, color: warna),
        ),
      ),
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MunculBertahap(
            indeks: 0,
            child: Text(trip.title, style: text.headlineMedium),
          ),
          if (trip.startedAt != null) ...[
            const SizedBox(height: 6),
            MunculBertahap(
              indeks: 1,
              child: Text(
                DateFormat("EEEE, d MMMM yyyy", 'id_ID').format(trip.startedAt!),
                style: text.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 22),
          MunculBertahap(
            indeks: 2,
            child: Row(
              children: [
                _Angka(
                  nilai: trip.distanceKm,
                  desimal: 1,
                  satuan: 'km',
                  label: 'Ditempuh',
                ),
                const SizedBox(width: 12),
                _Angka(
                  nilai: trip.pointCount.toDouble(),
                  satuan: '',
                  label: 'Jejak',
                ),
                const SizedBox(width: 12),
                _Teks(nilai: _durasi(trip), label: 'Lama'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _durasi(Trip trip) {
    final mulai = trip.startedAt;
    final selesai = trip.endedAt ?? DateTime.now();
    if (mulai == null) return '—';
    final d = selesai.difference(mulai);
    if (d.inHours >= 24) return '${d.inDays} hari';
    if (d.inHours >= 1) return '${d.inHours} jam';
    return '${d.inMinutes} mnt';
  }
}

class _Angka extends StatelessWidget {
  const _Angka({
    required this.nilai,
    required this.satuan,
    required this.label,
    this.desimal = 0,
  });

  final double nilai;
  final String satuan;
  final String label;
  final int desimal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AngkaBerjalan(
                    nilai: nilai,
                    desimal: desimal,
                    gaya: text.titleLarge,
                  ),
                  if (satuan.isNotEmpty) Text(' $satuan', style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Teks extends StatelessWidget {
  const _Teks({required this.nilai, required this.label});

  final String nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            FittedBox(child: Text(nilai, style: text.titleLarge)),
            const SizedBox(height: 4),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Dua hal yang bisa dilakukan dengan perjalanan yang sudah terekam.
class _BarisAksi extends StatelessWidget {
  const _BarisAksi({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final bisaDirender = trip.pointCount >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: MunculBertahap(
        indeks: 3,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: bisaDirender
                    ? () => VideoSheet.tampilkan(context, trip)
                    : null,
                icon: const Icon(Icons.movie_creation_outlined, size: 20),
                label: const Text('Jadikan video'),
              ),
            ),
            if (trip.mode == TripMode.group) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/trip/${trip.id}/bareng'),
                  icon: const Icon(Icons.group_outlined, size: 20),
                  label: const Text('Rombongan'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Titik-titik yang punya catatan, disusun seperti garis waktu.
///
/// Sisanya tidak ditampilkan satu per satu — perjalanan itu cerita, bukan
/// daftar koordinat.
class _DaftarSinggahan extends StatelessWidget {
  const _DaftarSinggahan({required this.titik});

  final List<TripPoint> titik;

  @override
  Widget build(BuildContext context) {
    final bercatatan = titik.where((t) => t.note != null).toList();
    final text = Theme.of(context).textTheme;

    if (bercatatan.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 60),
          child: Text(
            titik.any((t) => t.coarse)
                ? 'Kamu melihat perjalanan ini sebagai tamu, jadi catatan dan '
                      'titik persisnya tidak ikut dibagikan.'
                : 'Belum ada catatan di perjalanan ini. Lain kali, singgah '
                      'sebentar dan tuliskan apa yang kamu temui.',
            style: text.bodySmall,
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: bercatatan.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 16),
            child: Text('Singgahan', style: text.titleLarge),
          );
        }

        final t = bercatatan[index - 1];
        final terakhir = index == bercatatan.length;

        return Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, terakhir ? 60 : 0),
          child: MunculBertahap(
            indeks: index,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Garis waktu di kiri: titik dan garis penghubung, supaya
                  // singgahan terbaca berurutan sepanjang perjalanan.
                  Column(
                    children: [
                      Container(
                        height: 11,
                        width: 11,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: NapakColors.base,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NapakColors.deepAccent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      if (!terakhir)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: NapakColors.divider,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: terakhir ? 0 : 18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: NapakColors.warmNeutral,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(t.recordedAt),
                                  style: text.labelMedium?.copyWith(
                                    color: NapakColors.deepAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  t.transportMode.label,
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(t.note!, style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MemuatDetail extends StatelessWidget {
  const _MemuatDetail();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NapakSkeleton(tinggi: 340, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NapakSkeleton.teks(lebar: 200),
              SizedBox(height: 12),
              NapakSkeleton.teks(lebar: 140),
              SizedBox(height: 24),
              NapakSkeleton(tinggi: 86, radius: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _Galat extends StatelessWidget {
  const _Galat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          pesan,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
