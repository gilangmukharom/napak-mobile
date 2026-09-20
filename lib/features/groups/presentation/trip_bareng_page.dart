import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../trips/data/trip_models.dart';
import '../../trips/presentation/peta_rute.dart';
import '../application/live_location_controller.dart';

final _tripProvider = FutureProvider.autoDispose.family<Trip, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).detail(tripId),
);

final _pointsProvider = FutureProvider.autoDispose
    .family<List<TripPoint>, String>(
      (ref, tripId) => ref.watch(tripRepositoryProvider).points(tripId),
    );

/// Peta bersama satu rombongan.
///
/// Rute tiap orang digambar dengan warnanya sendiri, dan posisi langsung
/// muncul sebagai penanda berlabel nama — tapi hanya untuk yang memang
/// menyalakan berbagi posisi. Yang tidak menyalakan tetap kelihatan sebagai
/// anggota, rutenya tetap tergambar, posisinya saja yang tidak.
class TripBarengPage extends ConsumerStatefulWidget {
  const TripBarengPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripBarengPage> createState() => _TripBarengPageState();
}

class _TripBarengPageState extends ConsumerState<TripBarengPage> {
  final _petaController = PetaRuteController();

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(_tripProvider(widget.tripId));
    final anggota = ref.watch(memberListProvider(widget.tripId));
    final titik = ref.watch(_pointsProvider(widget.tripId));
    final live = ref.watch(liveLocationControllerProvider(widget.tripId));

    // Penanda posisi diperbarui langsung di peta, tanpa membangun ulang
    // MapLibreMap — rombongan yang ramai berarti pembaruan tiap beberapa detik.
    ref.listen(
      liveLocationControllerProvider(
        widget.tripId,
      ).select((s) => s.posisi),
      (_, posisi) {
        final warna = {
          for (final m in anggota.value ?? const <TripMember>[])
            m.userId: m.routeColor,
        };
        _petaController.perbaruiPosisiLangsung(posisi.values, warna);
      },
    );

    ref.listen(
      liveLocationControllerProvider(widget.tripId).select((s) => s.pesan),
      (_, pesan) {
        if (pesan == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesan)));
        ref
            .read(liveLocationControllerProvider(widget.tripId).notifier)
            .hapusPesan();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Bareng'),
        actions: [
          _LampuSambungan(tersambung: live.tersambung),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: titik.when(
              loading: () => const PetaKosong(),
              error: (_, _) => const PetaKosong(),
              data: (daftar) => daftar.isEmpty
                  ? const PetaKosong()
                  : PetaRute(
                      controller: _petaController,
                      jalur: _jalurPerAnggota(
                        daftar,
                        anggota.value ?? const [],
                      ),
                    ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                _KartuBerbagiPosisi(tripId: widget.tripId, live: live),
                const SizedBox(height: 28),
                Text(
                  'Teman seperjalanan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...anggota.when(
                  loading: () => [const _Memuat()],
                  error: (error, _) => [
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  data: (daftar) => [
                    for (final m in daftar)
                      _BarisAnggota(
                        anggota: m,
                        sedangTerlihat: live.posisi.containsKey(m.userId),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                trip.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (data) => _KartuUndangan(trip: data),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Memecah jejak jadi satu jalur per orang, memakai warna dari server.
  ///
  /// Warnanya sengaja datang dari backend, bukan diundi di HP — supaya biru
  /// yang kamu lihat untuk si A sama dengan biru yang dilihat semua orang.
  List<JalurRute> _jalurPerAnggota(
    List<TripPoint> titik,
    List<TripMember> anggota,
  ) {
    if (anggota.isEmpty) {
      return [
        JalurRute(
          id: 'utama',
          titik: [for (final t in titik) LatLng(t.lat, t.lng)],
        ),
      ];
    }

    return [
      for (final m in anggota)
        JalurRute(
          id: m.userId,
          nama: m.name,
          warna: m.routeColor,
          titik: [
            for (final t in titik.where((t) => t.recordedBy == m.userId))
              LatLng(t.lat, t.lng),
          ],
        ),
    ];
  }
}

class _LampuSambungan extends StatelessWidget {
  const _LampuSambungan({required this.tersambung});

  final bool tersambung;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tersambung
          ? 'Tersambung ke rombongan'
          : 'Belum tersambung ke rombongan',
      child: Container(
        height: 9,
        width: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tersambung ? NapakColors.affirm : NapakColors.divider,
        ),
      ),
    );
  }
}

class _KartuBerbagiPosisi extends ConsumerWidget {
  const _KartuBerbagiPosisi({required this.tripId, required this.live});

  final String tripId;
  final LiveState live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NapakColors.softSky,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Bagikan posisimu', style: text.titleMedium),
              ),
              Switch(
                value: live.berbagiSendiri,
                onChanged: (nyala) => ref
                    .read(liveLocationControllerProvider(tripId).notifier)
                    .aturBerbagi(nyala: nyala),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            live.berbagiSendiri
                ? 'Teman seperjalanan bisa melihat posisimu selama perjalanan '
                      'ini. Matikan kapan saja — berlaku seketika.'
                : 'Mati. Rutemu tetap tergambar di peta bersama, tapi posisimu '
                      'saat ini tidak dibagikan.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: NapakColors.deepAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Izin ini hanya untuk perjalanan ini, tidak terbawa ke '
                  'perjalanan berikutnya.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarisAnggota extends StatelessWidget {
  const _BarisAnggota({required this.anggota, required this.sedangTerlihat});

  final TripMember anggota;
  final bool sedangTerlihat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final warna = _hexKeColor(anggota.routeColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 4,
            decoration: BoxDecoration(
              color: warna,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(anggota.name, style: text.bodyLarge),
                    if (anggota.isLeader) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NapakColors.warmNeutral,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Pemimpin', style: text.labelMedium),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${anggota.distanceKm.toStringAsFixed(1)} km · '
                  '${sedangTerlihat ? 'posisinya terlihat sekarang' : anggota.liveLocationEnabled ? 'berbagi posisi, menunggu kabar' : 'tidak berbagi posisi'}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (sedangTerlihat)
            const Icon(
              Icons.my_location_rounded,
              size: 18,
              color: NapakColors.deepAccent,
            ),
        ],
      ),
    );
  }

  static Color _hexKeColor(String hex) {
    final bersih = hex.replaceFirst('#', '');
    return Color(int.parse('FF$bersih', radix: 16));
  }
}

class _KartuUndangan extends StatelessWidget {
  const _KartuUndangan({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slug = trip.shareSlug;

    if (!trip.isOwner) return const SizedBox.shrink();

    if (slug == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NapakColors.warmNeutral,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajak teman', style: text.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Perjalanan ini masih tertutup. Buka aksesnya lewat tautan dulu '
              'supaya teman bisa gabung.',
              style: text.bodySmall,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NapakColors.warmNeutral,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajak teman', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Bagikan kode ini. Yang punya kodenya bisa ikut merekam di '
            'perjalanan yang sama.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    slug,
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Salin',
                icon: const Icon(Icons.copy_rounded, size: 20),
                color: NapakColors.deepAccent,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: slug));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode undangan tersalin.')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Bagikan',
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                color: NapakColors.deepAccent,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Ikut jalan bareng di Napak yuk. '
                        'Masukkan kode ini di aplikasi: $slug',
                    subject: trip.title,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Memuat extends StatelessWidget {
  const _Memuat();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}
