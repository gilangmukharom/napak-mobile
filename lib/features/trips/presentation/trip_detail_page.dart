import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../../core/widgets/tourvella_skeleton.dart';
import '../../recording/application/recording_controller.dart';
import '../../obrolan/data/obrolan_data.dart';
import '../../profil/presentation/penampil_media.dart';
import '../../render/presentation/video_sheet.dart';
import '../../sosial/presentation/kirim_kartu_pos_sheet.dart';
import '../../sosial/presentation/undang_teman_sheet.dart';
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
    ref.listen(recordingControllerProvider.select((s) => s.latest), (
      sebelum,
      sekarang,
    ) {
      final rekaman = ref.read(recordingControllerProvider);
      if (sekarang == null || rekaman.tripId != widget.tripId) return;
      _petaController.tambahTitik(
        _jalurUtama,
        LatLng(sekarang.lat, sekarang.lng),
      );
    });

    return Scaffold(
      backgroundColor: TourvellaColors.base,
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
              onEkspor: () => _ekspor(context, data),
            ),
            SliverToBoxAdapter(child: _Ringkasan(trip: data)),
            SliverToBoxAdapter(child: _BarisAksi(trip: data)),
            if (data.isOwner)
              SliverToBoxAdapter(child: _SakelarProfil(trip: data)),
            titik.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TourvellaSkeleton.teks(lebar: 120),
                      SizedBox(height: 16),
                      TourvellaSkeleton(tinggi: 76, radius: 16),
                    ],
                  ),
                ),
              ),
              error: (error, _) =>
                  SliverToBoxAdapter(child: _Galat(pesan: error.toString())),
              data: (daftar) =>
                  _DaftarSinggahan(titik: daftar, bolehKirim: data.isOwner),
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
                style: TextStyle(
                  color: TourvellaColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            for (final v in TripVisibility.values)
              ListTile(
                leading: Icon(
                  _ikonVisibility(v),
                  color: TourvellaColors.deepAccent,
                ),
                title: Text(v.label),
                trailing: trip.visibility == v
                    ? const Icon(
                        Icons.check_rounded,
                        color: TourvellaColors.deepAccent,
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

  /// Bawa perjalanan ini keluar dari Tourvella.
  Future<void> _ekspor(BuildContext context, Trip trip) async {
    try {
      final folder = await getTemporaryDirectory();
      final nama = trip.title
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final berkas = File('${folder.path}/tourvella-$nama.gpx');

      await ref.read(tripRepositoryProvider).unduhGpx(trip.id, berkas.path);

      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(berkas.path, mimeType: 'application/gpx+xml')],
          text: '${trip.title} — jejak lengkap dalam format GPX',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _hapus(BuildContext context, Trip trip) async {
    final controller = TextEditingController();

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TourvellaColors.base,
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
              backgroundColor: TourvellaColors.attention,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesan)));
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
    required this.onEkspor,
  });

  final Trip trip;
  final AsyncValue<List<TripPoint>> titik;
  final PetaRuteController peta;
  final String jalurId;
  final VoidCallback onVisibility;
  final VoidCallback onHapus;
  final VoidCallback onEkspor;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: TourvellaColors.base,
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
        _TombolBulat(ikon: Icons.ios_share_rounded, onTap: onEkspor),
        if (trip.isOwner)
          _TombolBulat(
            ikon: Icons.delete_outline_rounded,
            warna: TourvellaColors.attention,
            onTap: onHapus,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            titik.when(
              loading: () => const PetaKosong(),
              error: (_, _) => const PetaKosong(),
              data: (daftar) => daftar.isEmpty
                  ? const PetaKosong()
                  // Peta muncul memudar, bukan berkedip masuk — tile-nya butuh
                  // waktu, dan kedipan itu yang paling terasa murah.
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: TourvellaMotion.lambat,
                      curve: TourvellaMotion.mengalir,
                      builder: (context, t, anak) =>
                          Opacity(opacity: t, child: anak),
                      child: PetaRute(
                        controller: peta,
                        jalur: [
                          JalurRute(
                            id: jalurId,
                            titik: [
                              for (final t in daftar) LatLng(t.lat, t.lng),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),

            // Kerudung gelap di dua ujung: tombol di atas tetap terbaca di
            // atas warna peta apa pun, dan bawahnya menyambung ke panel.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      TourvellaColors.malam.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.transparent,
                      TourvellaColors.malam.withValues(alpha: 0.5),
                    ],
                    stops: const [0, 0.24, 0.62, 1],
                  ),
                ),
              ),
            ),
          ],
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
    this.warna = TourvellaColors.base,
  });

  final IconData ikon;
  final VoidCallback? onTap;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TourvellaPressable(
        skala: 0.88,
        onTap: onTap ?? () => context.pop(),
        child: Container(
          height: 36,
          width: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: TourvellaColors.malam.withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(
              color: TourvellaColors.base.withValues(alpha: 0.18),
            ),
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
                DateFormat(
                  "EEEE, d MMMM yyyy",
                  'id_ID',
                ).format(trip.startedAt!),
                style: text.bodySmall,
              ),
            ),
          ],
          if (trip.retraceOf != null) ...[
            const SizedBox(height: 16),
            MunculBertahap(
              indeks: 2,
              child: _KaitanSusurUlang(lama: trip.retraceOf!),
            ),
          ],
          const SizedBox(height: 22),
          MunculBertahap(indeks: 2, child: _PanelJarak(trip: trip)),
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

/// Panel instrumen perjalanan: jarak, lama, jumlah jejak.
///
/// Sebelumnya tiga kartu biru pastel sejajar — terbaca sebagai tiga kotak
/// informasi, bukan sebagai catatan perjalanan. Satu panel gelap berkontur
/// membuat angkanya terbaca seperti odometer di dasbor, dan jaraknya —
/// satu-satunya angka yang benar-benar ditunggu orang — dapat tempat
/// terbesar.
class _PanelJarak extends StatelessWidget {
  const _PanelJarak({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: TourvellaColors.malam,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TourvellaColors.kontur),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.2, jumlahGaris: 4, benih: 7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelKapital(
                  'Ditempuh',
                  warna: TourvellaColors.emberRedup,
                ),
                const SizedBox(height: 4),
                Odometer(
                  nilai: trip.distanceKm,
                  desimal: 1,
                  satuan: 'KM',
                  gaya: text.displaySmall?.copyWith(
                    color: TourvellaColors.ember,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const PemisahJalur(warna: TourvellaColors.kontur),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Sel(label: 'Lama', nilai: _Ringkasan._durasi(trip)),
                    Container(
                      width: 1,
                      height: 30,
                      color: TourvellaColors.kontur,
                    ),
                    _Sel(label: 'Jejak', nilai: '${trip.pointCount}'),
                    Container(
                      width: 1,
                      height: 30,
                      color: TourvellaColors.kontur,
                    ),
                    _Sel(
                      label: 'Berangkat',
                      nilai: trip.startedAt == null
                          ? '—'
                          : DateFormat('HH.mm').format(trip.startedAt!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sel extends StatelessWidget {
  const _Sel({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        children: [
          LabelKapital(
            label,
            warna: TourvellaColors.base.withValues(alpha: 0.5),
            ukuran: 10,
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              nilai,
              style: text.titleLarge?.copyWith(
                color: TourvellaColors.base,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        child: Column(
          children: [
            // Cerita ditaruh paling depan: inilah cara paling menyenangkan
            // membuka kembali sebuah perjalanan, dan yang paling jarang
            // ditemukan orang kalau disembunyikan di menu.
            FilledButton.icon(
              onPressed: () => context.push('/trip/${trip.id}/cerita'),
              icon: const Icon(Icons.auto_stories_outlined, size: 20),
              label: const Text('Buka ceritanya'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: bisaDirender
                        ? () => VideoSheet.tampilkan(context, trip)
                        : null,
                    icon: const Icon(Icons.movie_creation_outlined, size: 20),
                    label: const Text('Video'),
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
            if (trip.mode == TripMode.group) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _TombolObrolanRombongan(trip: trip)),
                  if (trip.isOwner) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            UndangTemanSheet.tampilkan(context, trip.id),
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 20,
                        ),
                        label: const Text('Undang'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TombolObrolanRombongan extends ConsumerStatefulWidget {
  const _TombolObrolanRombongan({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_TombolObrolanRombongan> createState() =>
      _TombolObrolanRombonganState();
}

class _TombolObrolanRombonganState
    extends ConsumerState<_TombolObrolanRombongan> {
  bool _membuka = false;

  Future<void> _buka() async {
    setState(() => _membuka = true);
    try {
      final id = await ref
          .read(obrolanRepositoryProvider)
          .ruangPerjalanan(widget.trip.id);
      if (!mounted) return;
      await context.push(
        '/obrolan/$id',
        extra: (judul: widget.trip.title, rombongan: true),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _membuka = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _membuka ? null : _buka,
      icon: const Icon(Icons.forum_outlined, size: 20),
      label: const Text('Obrolan'),
    );
  }
}

/// Titik-titik yang punya catatan, disusun seperti garis waktu.
///
/// Sisanya tidak ditampilkan satu per satu — perjalanan itu cerita, bukan
/// daftar koordinat.
class _DaftarSinggahan extends StatelessWidget {
  const _DaftarSinggahan({required this.titik, required this.bolehKirim});

  final List<TripPoint> titik;

  /// Kartu pos hanya bisa dikirim dari perjalanan sendiri.
  final bool bolehKirim;

  @override
  Widget build(BuildContext context) {
    // Singgahan itu titik yang sengaja ditandai — entah dengan kalimat,
    // entah dengan foto. Dua-duanya sama-sama layak masuk garis waktu.
    final bercatatan = titik
        .where((t) => t.note != null || t.photoUrl != null)
        .toList();
    final text = Theme.of(context).textTheme;

    // Semua media di perjalanan ini, supaya penampil layar penuh bisa
    // digeser dari satu singgahan ke singgahan berikutnya.
    final media = [
      for (final t in bercatatan)
        if (t.photoUrl != null)
          MediaTampil(
            id: t.id,
            url: t.photoUrl!,
            video: t.video,
            posterUrl: t.posterUrl,
            catatan: t.note,
            pada: t.recordedAt,
          ),
    ];

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
                          color: TourvellaColors.base,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TourvellaColors.deepAccent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      if (!terakhir)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: TourvellaColors.divider,
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
                          color: TourvellaColors.warmNeutral,
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
                                    color: TourvellaColors.deepAccent,
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
                            if (t.photoUrl != null) ...[
                              const SizedBox(height: 12),
                              _FotoSinggahan(
                                titik: t,
                                onTap: () => PenampilMedia.buka(
                                  context,
                                  media,
                                  media.indexWhere((m) => m.id == t.id),
                                ),
                              ),
                              // Kartu pos cuma dari foto; video tidak bisa
                              // dicetak di kartu.
                              if (bolehKirim && !t.video)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        KirimKartuPosSheet.tampilkan(
                                          context,
                                          titikId: t.id,
                                          fotoUrl: t.photoUrl!,
                                        ),
                                    icon: const Icon(
                                      Icons.local_post_office_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Kirim sebagai kartu pos',
                                    ),
                                  ),
                                ),
                            ],
                            if (t.note != null) ...[
                              const SizedBox(height: 10),
                              Text(t.note!, style: text.bodyMedium),
                            ],
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
        TourvellaSkeleton(tinggi: 340, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TourvellaSkeleton.teks(lebar: 200),
              SizedBox(height: 12),
              TourvellaSkeleton.teks(lebar: 140),
              SizedBox(height: 24),
              TourvellaSkeleton(tinggi: 86, radius: 18),
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

/// Foto singgahan.
///
/// URL-nya bertanda tangan dan berumur pendek — dibuat ulang tiap kali jejak
/// dibaca, bukan disimpan. Tautan yang bocor mati dengan sendirinya.
class _FotoSinggahan extends StatelessWidget {
  const _FotoSinggahan({required this.titik, required this.onTap});

  final TripPoint titik;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = titik.gambarDiam;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'media-${titik.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url == null)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: TourvellaColors.routeGradient,
                      ),
                    ),
                  )
                else
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, anak, kemajuan) {
                      if (kemajuan == null) return anak;
                      return const TourvellaSkeleton(
                        tinggi: double.infinity,
                        radius: 0,
                      );
                    },
                    // Tautan bertanda tangan bisa kedaluwarsa kalau halamannya dibiarkan
                    // terbuka lama. Yang tampil kemudian adalah penjelasan, bukan ikon
                    // rusak tanpa keterangan.
                    errorBuilder: (context, galat, jejak) => Container(
                      color: TourvellaColors.softSky,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_not_supported_outlined,
                            size: 22,
                            color: TourvellaColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fotonya belum termuat.\nTarik ke bawah untuk menyegarkan.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (titik.video)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TourvellaColors.textPrimary.withValues(
                          alpha: 0.45,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 34,
                        color: TourvellaColors.textOnDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sakelar "pajang di profil" — mati bawaan.
class _SakelarProfil extends ConsumerStatefulWidget {
  const _SakelarProfil({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_SakelarProfil> createState() => _SakelarProfilState();
}

class _SakelarProfilState extends ConsumerState<_SakelarProfil> {
  late bool _nyala = widget.trip.diProfil;
  bool _sibuk = false;

  Future<void> _ubah(bool nyala) async {
    setState(() {
      _nyala = nyala;
      _sibuk = true;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .setDiProfil(widget.trip.id, pajang: nyala);
      ref.invalidate(_tripDetailProvider(widget.trip.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nyala
                ? 'Dipajang. Muncul di linimasa dan profilmu untuk teman.'
                : 'Diturunkan dari profil. Hanya kamu yang bisa melihatnya.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _nyala = !nyala);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: AnimatedContainer(
        duration: TourvellaMotion.sedang,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: _nyala
              ? TourvellaColors.softSky
              : TourvellaColors.softSky.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: TourvellaMotion.cepat,
              child: Icon(
                _nyala ? Icons.grid_on_rounded : Icons.lock_outline_rounded,
                key: ValueKey(_nyala),
                color: TourvellaColors.deepAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pajang di profil', style: text.titleSmall),
                  Text(
                    _nyala
                        ? 'Muncul di linimasa teman, beserta foto dan ceritanya.'
                        : 'Hanya kamu yang melihat perjalanan ini.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: _nyala, onChanged: _sibuk ? null : _ubah),
          ],
        ),
      ),
    );
  }
}

/// Menandai bahwa perjalanan ini mengulang perjalanan lama.
///
/// Bisa diketuk untuk membuka yang lama — dan dari sana, kalau yang lama juga
/// menyusuri ulang sesuatu, rantainya bisa ditelusuri terus ke belakang.
class _KaitanSusurUlang extends StatelessWidget {
  const _KaitanSusurUlang({required this.lama});

  final RingkasTrip lama;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return TourvellaPressable(
      onTap: () => context.push('/trip/${lama.id}'),
      skala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TourvellaColors.warmNeutral,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 18,
              color: TourvellaColors.deepAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menyusuri ulang', style: text.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    lama.startedAt == null
                        ? lama.title
                        : '${lama.title} · ${DateFormat("MMMM yyyy", 'id_ID').format(lama.startedAt!)}',
                    style: text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: TourvellaColors.deepAccent,
            ),
          ],
        ),
      ),
    );
  }
}
