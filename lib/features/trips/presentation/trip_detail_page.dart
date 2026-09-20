import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
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

    // Saat perjalanan ini yang sedang direkam, titik baru ditambahkan ke peta
    // satu per satu — bukan dengan memuat ulang seluruh rute dari server.
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
      body: trip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Galat(pesan: error.toString()),
        data: (data) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: NapakColors.base,
              surfaceTintColor: Colors.transparent,
              leading: const BackButton(color: NapakColors.deepAccent),
              actions: [
                IconButton(
                  tooltip: 'Siapa yang boleh melihat',
                  icon: Icon(_ikonVisibility(data.visibility)),
                  color: NapakColors.deepAccent,
                  onPressed: data.isOwner
                      ? () => _aturVisibility(context, data)
                      : null,
                ),
                if (data.isOwner)
                  IconButton(
                    tooltip: 'Hapus permanen',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: NapakColors.attention,
                    onPressed: () => _hapus(context, data),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: titik.when(
                  loading: () => const PetaKosong(),
                  error: (_, _) => const PetaKosong(),
                  data: (daftar) => daftar.isEmpty
                      ? const PetaKosong()
                      : PetaRute(
                          controller: _petaController,
                          jalur: [
                            JalurRute(
                              id: _jalurUtama,
                              titik: [
                                for (final t in daftar) LatLng(t.lat, t.lng),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _Ringkasan(trip: data)),
            SliverToBoxAdapter(child: _BarisAksi(trip: data)),
            titik.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _Galat(pesan: error.toString()),
              ),
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
                style: TextStyle(
                  color: NapakColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            for (final v in TripVisibility.values)
              ListTile(
                leading: Icon(
                  _ikonVisibility(v),
                  color: NapakColors.deepAccent,
                ),
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

    await ref
        .read(tripRepositoryProvider)
        .setVisibility(trip.id, pilihan);
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
              'Seluruh jejak, catatan, dan fotonya dihapus sepenuhnya dari '
              'Napak. Tidak disembunyikan — benar-benar hilang, dan tidak bisa '
              'dikembalikan.',
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

/// Dua hal yang bisa dilakukan dengan sebuah perjalanan yang sudah terekam:
/// dijadikan video untuk dibagikan, dan — kalau ini Trip Bareng — dibuka
/// peta rombongannya.
class _BarisAksi extends StatelessWidget {
  const _BarisAksi({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final bisaDirender = trip.pointCount >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
          Text(trip.title, style: text.headlineSmall),
          if (trip.startedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              DateFormat("EEEE, d MMMM yyyy", 'id_ID').format(trip.startedAt!),
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              _Angka(
                nilai: trip.distanceKm.toStringAsFixed(1),
                satuan: 'km',
                label: 'Ditempuh',
              ),
              const SizedBox(width: 14),
              _Angka(
                nilai: '${trip.pointCount}',
                satuan: '',
                label: 'Jejak',
              ),
              const SizedBox(width: 14),
              _Angka(
                nilai: _durasi(trip),
                satuan: '',
                label: 'Lama',
              ),
            ],
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
  });

  final String nilai;
  final String satuan;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: nilai,
                style: text.titleLarge,
                children: [
                  if (satuan.isNotEmpty)
                    TextSpan(text: ' $satuan', style: text.bodySmall),
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

/// Titik-titik yang punya catatan. Sisanya tidak perlu ditampilkan satu-satu —
/// perjalanan adalah cerita, bukan daftar koordinat.
class _DaftarSinggahan extends StatelessWidget {
  const _DaftarSinggahan({required this.titik});

  final List<TripPoint> titik;

  @override
  Widget build(BuildContext context) {
    final bercatatan = titik.where((t) => t.note != null).toList();

    if (bercatatan.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          child: Text(
            titik.any((t) => t.coarse)
                ? 'Kamu melihat perjalanan ini sebagai tamu, jadi catatan dan '
                      'titik persisnya tidak ikut dibagikan.'
                : 'Belum ada catatan di perjalanan ini. Lain kali, singgah '
                      'sebentar dan tuliskan apa yang kamu temui.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: bercatatan.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
            child: Text(
              'Singgahan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
        }

        final t = bercatatan[index - 1];
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            index == bercatatan.length ? 48 : 0,
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NapakColors.warmNeutral,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: NapakColors.deepAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(t.recordedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t.transportMode.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.note!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
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
