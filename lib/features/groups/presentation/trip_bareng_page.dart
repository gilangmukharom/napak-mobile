import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../trips/data/trip_models.dart';
import '../../trips/presentation/peta_rute.dart';
import '../application/live_location_controller.dart';
import 'panel_konvoi.dart';
import '../../peta/presentation/layanan_sheet.dart';

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
      liveLocationControllerProvider(widget.tripId).select((s) => s.posisi),
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
      appBar: BilahEkspedisi(
        judul: 'Trip Bareng',
        keterangan: live.tersambung ? 'Tersambung' : 'Mencari rombongan',
        aksi: [
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
                // Barisan konvoi muncul begitu ada dua orang yang berbagi
                // posisi — sebelum itu memang belum ada barisan.
                AnimatedSize(
                  duration: TourvellaMotion.sedang,
                  curve: TourvellaMotion.mengalir,
                  child: live.konvoi == null || live.konvoi!.barisan.length < 2
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: PanelKonvoi(kabar: live.konvoi!),
                        ),
                ),
                _PanelSinyal(tripId: widget.tripId, live: live),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => LayananSheet.tampilkan(context),
                  icon: const Icon(Icons.local_gas_station_rounded, size: 20),
                  label: const Text('SPBU & bengkel terdekat'),
                ),
                const SizedBox(height: 22),
                _KartuBerbagiPosisi(tripId: widget.tripId, live: live),
                const SizedBox(height: 28),
                const LabelKapital(
                  'Teman seperjalanan',
                  warna: TourvellaColors.deepAccent,
                  ukuran: 12,
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
          color: tersambung ? TourvellaColors.affirm : TourvellaColors.kontur,
          boxShadow: tersambung
              ? [
                  BoxShadow(
                    color: TourvellaColors.affirm.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
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
        color: TourvellaColors.softSky,
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
                color: TourvellaColors.deepAccent,
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
                          color: TourvellaColors.warmNeutral,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Pemimpin', style: text.labelMedium),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${anggota.distanceKm.toStringAsFixed(1)} km · '
                  '${sedangTerlihat
                      ? 'posisinya terlihat sekarang'
                      : anggota.liveLocationEnabled
                      ? 'berbagi posisi, menunggu kabar'
                      : 'tidak berbagi posisi'}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (sedangTerlihat)
            const Icon(
              Icons.my_location_rounded,
              size: 18,
              color: TourvellaColors.deepAccent,
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
          color: TourvellaColors.warmNeutral,
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
        color: TourvellaColors.warmNeutral,
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
                color: TourvellaColors.deepAccent,
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
                color: TourvellaColors.deepAccent,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Ikut jalan bareng di Tourvella yuk. '
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

/// Ikon untuk tiap sinyal.
///
/// Dipetakan di sini, bukan di model: lapisan data tidak perlu tahu apa-apa
/// soal Material.
IconData _ikonSinyal(Sinyal s) => switch (s) {
  Sinyal.isiBensin => Icons.local_gas_station_outlined,
  Sinyal.nunggu => Icons.pin_drop_outlined,
  Sinyal.jalanDuluan => Icons.fast_forward_outlined,
  Sinyal.istirahat => Icons.local_cafe_outlined,
  Sinyal.adaMasalah => Icons.warning_amber_rounded,
  Sinyal.sampai => Icons.flag_outlined,
};

/// Sinyal satu ketuk.
///
/// Ini pengganti chat, dan bukan karena chat sulit dibuat. Rombongan touring
/// sudah ada di WhatsApp, dan di atas motor tidak ada yang mengetik. Yang
/// dibutuhkan saat jalan itu isyarat sekali ketuk dengan sarung tangan.
///
/// Tombolnya besar-besar dengan sengaja — ini satu-satunya bagian aplikasi
/// yang dirancang untuk ditekan sambil berhenti di lampu merah.
class _PanelSinyal extends ConsumerWidget {
  const _PanelSinyal({required this.tripId, required this.live});

  final String tripId;
  final LiveState live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Kabari rombongan', style: text.titleLarge),
            const SizedBox(width: 8),
            if (!live.tersambung)
              Text('· belum tersambung', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sekali ketuk, langsung sampai ke semua yang sedang menonton.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in Sinyal.values)
              _TombolSinyal(
                sinyal: s,
                aktif: live.tersambung,
                onTap: () => ref
                    .read(liveLocationControllerProvider(tripId).notifier)
                    .kirimSinyal(s),
              ),
          ],
        ),

        // Riwayatnya cuma di memori dan cuma delapan terakhir. Ini alat
        // koordinasi saat jalan, bukan riwayat percakapan.
        AnimatedSize(
          duration: TourvellaMotion.sedang,
          curve: TourvellaMotion.mengalir,
          child: live.sinyal.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, m) in live.sinyal.take(4).indexed)
                        MunculBertahap(
                          indeks: i,
                          jarakGeser: 10,
                          child: _BarisSinyal(masuk: m),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TombolSinyal extends StatelessWidget {
  const _TombolSinyal({
    required this.sinyal,
    required this.aktif,
    required this.onTap,
  });

  final Sinyal sinyal;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // "Ada masalah" diberi warna hangat, bukan merah menyala. Ini isyarat
    // minta berhenti, bukan alarm kebakaran — dan palet Tourvella memang tidak
    // punya warna yang berteriak.
    final mendesak = sinyal == Sinyal.adaMasalah;
    final latar = mendesak ? TourvellaColors.warmNeutral : Colors.white;

    return TourvellaPressable(
      onTap: aktif ? onTap : null,
      skala: 0.94,
      child: AnimatedOpacity(
        duration: TourvellaMotion.cepat,
        opacity: aktif ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: latar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mendesak
                  ? TourvellaColors.attention
                  : TourvellaColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _ikonSinyal(sinyal),
                size: 18,
                color: mendesak
                    ? TourvellaColors.attention
                    : TourvellaColors.deepAccent,
              ),
              const SizedBox(width: 9),
              Text(sinyal.label, style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisSinyal extends StatelessWidget {
  const _BarisSinyal({required this.masuk});

  final SinyalMasuk masuk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            _ikonSinyal(masuk.sinyal),
            size: 16,
            color: TourvellaColors.deepAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: masuk.nama,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                children: [
                  TextSpan(text: ' — ${masuk.pesan}', style: text.bodyMedium),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(DateFormat('HH:mm').format(masuk.pada), style: text.bodySmall),
        ],
      ),
    );
  }
}
