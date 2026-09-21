import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/theme/napak_tekstur.dart';
import '../../../core/widgets/napak_ekspedisi.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../../core/widgets/napak_skeleton.dart';
import '../../obrolan/data/obrolan_data.dart';
import '../../recording/application/recording_controller.dart';
import '../../sosial/data/sosial_repository.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../data/trip_models.dart';
import 'pratinjau_rute.dart';

/// Beranda: jejak-jejakmu, yang terbaru di atas.
///
/// Disusun seperti feed karena yang dilihat orang di sini bukan data,
/// melainkan kenangan. Bentuk rutenya tampil besar dan lebih dulu; angka
/// jarak dan tanggal menyusul di bawahnya sebagai keterangan — bukan
/// sebaliknya.
class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);
    final nama = ref.watch(savedNameProvider).value;
    final merekam = ref.watch(recordingControllerProvider);

    return Scaffold(
      backgroundColor: NapakColors.base,
      body: RefreshIndicator(
        color: NapakColors.deepAccent,
        backgroundColor: Colors.white,
        onRefresh: () async => ref.invalidate(tripListProvider),
        child: CustomScrollView(
          slivers: [
            _Sapaan(nama: nama, trips: trips.value ?? const []),
            const SliverToBoxAdapter(child: _AntreanJejak()),
            const SliverToBoxAdapter(child: _Kenangan()),
            if (merekam.isRecording)
              SliverToBoxAdapter(
                child: _SedangMerekam(judul: merekam.title ?? 'Perjalanan'),
              ),

            trips.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: SkeletonDaftarTrip(),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _Kosong(
                  ikon: Icons.cloud_off_rounded,
                  judul: 'Belum tersambung',
                  keterangan: error.toString(),
                  aksi: FilledButton(
                    onPressed: () => ref.invalidate(tripListProvider),
                    child: const Text('Coba lagi'),
                  ),
                ),
              ),
              data: (daftar) {
                if (daftar.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _Kosong(
                      ikon: Icons.route_outlined,
                      judul: 'Belum ada jejak di sini',
                      keterangan:
                          'Mulai perjalanan pertamamu. Napak merekam '
                          'diam-diam sementara kamu menikmati jalannya.',
                      aksi: FilledButton.icon(
                        onPressed: () => context.push('/rekam/mulai'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Mulai merekam'),
                      ),
                    ),
                  );
                }

                return SliverList.separated(
                  itemCount: daftar.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      i == 0 ? 14 : 0,
                      20,
                      i == daftar.length - 1 ? 110 : 0,
                    ),
                    child: MunculBertahap(
                      indeks: i,
                      child: _KartuTrip(trip: daftar[i]),
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
}

/// Sapaan yang mengecil saat digulir.
///
/// Judul besar memberi ruang bernapas saat halaman baru dibuka, lalu
/// menyingkir sendiri begitu orang mulai membaca isinya.
/// Kepala beranda: panorama malam dengan punggungan gunung.
///
/// Versi pertama cuma sapaan dan nama di atas latar putih — rapi, dan tidak
/// memberi tahu apa pun tentang aplikasi apa ini. Sekarang yang pertama
/// terlihat adalah langit sebelum berangkat, jarak yang sudah ditempuh, dan
/// gunung yang bergeser pelan saat daftar digulir.
class _Sapaan extends ConsumerStatefulWidget {
  const _Sapaan({required this.nama, required this.trips});

  final String? nama;
  final List<Trip> trips;

  @override
  ConsumerState<_Sapaan> createState() => _SapaanState();
}

class _SapaanState extends ConsumerState<_Sapaan> {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kabar = ref.watch(jumlahKabarProvider).value ?? 0;
    final pesan = (ref.watch(daftarObrolanProvider).value ?? const [])
        .fold<int>(0, (n, p) => n + p.belumDibaca);
    final totalKm = widget.trips.fold<double>(0, (j, t) => j + t.distanceKm);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 232,
      backgroundColor: NapakColors.malam,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NapakColors.base,
      title: Text(
        'Jejakmu',
        style: text.titleLarge?.copyWith(color: NapakColors.base),
      ),
      actions: [
        IkonBerlencana(
          ikon: Icons.forum_outlined,
          jumlah: pesan,
          label: 'Obrolan',
          warna: NapakColors.base,
          onTap: () async {
            await context.push('/obrolan');
            ref.invalidate(daftarObrolanProvider);
          },
        ),
        IkonBerlencana(
          ikon: Icons.notifications_none_rounded,
          jumlah: kabar,
          label: 'Kabar',
          warna: NapakColors.base,
          onTap: () async {
            await context.push('/inbox');
            ref.invalidate(jumlahKabarProvider);
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _PanoramaMalam(
          nama: widget.nama,
          totalKm: totalKm,
          jumlahPerjalanan: widget.trips.length,
        ),
      ),
    );
  }
}

class _PanoramaMalam extends StatelessWidget {
  const _PanoramaMalam({
    required this.nama,
    required this.totalKm,
    required this.jumlahPerjalanan,
  });

  final String? nama;
  final double totalKm;
  final int jumlahPerjalanan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: NapakColors.langitSubuh,
              stops: [0, 0.55, 1.35],
            ),
          ),
        ),
        // Matahari yang baru naik, di balik punggungan.
        Positioned(
          right: 44,
          bottom: 52,
          child:
              Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NapakColors.ember.withValues(alpha: 0.85),
                      boxShadow: [
                        BoxShadow(
                          color: NapakColors.ember.withValues(alpha: 0.45),
                          blurRadius: 60,
                          spreadRadius: 18,
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 6, end: -6, duration: 6.seconds)
                  .fade(begin: 0.82, end: 1, duration: 6.seconds),
        ),
        const IgnorePointer(child: KonturTopografi(opasitas: 0.18)),
        const SiluetGunung(
          warna: [Color(0xFF2E3B4E), NapakColors.malamNaik, NapakColors.malam],
        ),
        const ButiranKertas(opasitas: 0.04),

        // Sapaan dan odometer, menempel di dasar panorama.
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LabelKapital(
                _salam(),
                warna: NapakColors.base.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 2),
              Text(
                nama ?? 'Penjejak',
                style: text.headlineMedium?.copyWith(color: NapakColors.base),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Odometer(
                    nilai: totalKm,
                    desimal: totalKm < 100 ? 1 : 0,
                    satuan: 'KM DITEMPUH',
                    gaya: text.headlineSmall?.copyWith(
                      color: NapakColors.ember,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  LabelKapital(
                    '$jumlahPerjalanan perjalanan',
                    warna: NapakColors.base.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _salam() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 19) return 'Selamat sore';
    return 'Selamat malam';
  }
}

class _AntreanJejak extends ConsumerWidget {
  const _AntreanJejak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlah = ref.watch(pendingPointCountProvider).value ?? 0;

    // Tingginya menyusut sendiri jadi nol saat tidak ada apa-apa, bukan
    // menyisakan ruang kosong yang menunggu.
    return AnimatedSize(
      duration: NapakMotion.sedang,
      curve: NapakMotion.mengalir,
      child: jumlah == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: NapakColors.warmNeutral,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_sync_outlined,
                      size: 18,
                      color: NapakColors.deepAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$jumlah jejak menunggu sinyal. Sudah aman di HP-mu.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NapakColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SedangMerekam extends StatelessWidget {
  const _SedangMerekam({required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: NapakPressable(
        onTap: () => context.push('/rekam'),
        skala: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [NapakColors.softSky, NapakColors.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const TitikBerdenyut(warna: NapakColors.deepAccent, ukuran: 9),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sedang merekam', style: text.labelMedium),
                    Text(
                      judul,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: NapakColors.deepAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu perjalanan: bentuk rutenya dulu, keterangannya menyusul.
/// Kepala kartu perjalanan: fotonya, dengan bentuk rutenya di atasnya.
///
/// Sebelumnya cuma bentuk rute di atas blok pastel. Itu terbaca rapi, tapi
/// sepuluh kartu berikutnya terbaca rapi dengan cara yang persis sama —
/// daftar perjalanan jadi deretan garis biru yang sulit dibedakan.
///
/// Fotonya yang membedakan. Bentuk rutenya tetap digambar di atasnya, karena
/// itu yang memberi tahu perjalanan ini panjang lurus atau berkelok naik
/// gunung — hal yang tidak pernah diceritakan satu foto.
class _SampulTrip extends StatelessWidget {
  const _SampulTrip({required this.trip});

  final Trip trip;

  static const _tinggi = 168.0;

  @override
  Widget build(BuildContext context) {
    if (trip.coverUrl == null) {
      return PratinjauRute(titik: trip.previewPath, tinggi: _tinggi);
    }

    return SizedBox(
      height: _tinggi,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blok pastel di bawah fotonya. Ini yang terlihat selama fotonya
          // masih diunduh, jadi kartunya tidak pernah berlubang putih.
          const ColoredBox(color: NapakColors.softSky),

          Image.network(
            trip.coverUrl!,
            fit: BoxFit.cover,
            frameBuilder: (context, anak, frame, sinkron) {
              if (sinkron) return anak;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: NapakMotion.sedang,
                curve: NapakMotion.mengalir,
                child: anak,
              );
            },
            errorBuilder: (context, galat, jejak) => const SizedBox.shrink(),
          ),

          // Kerudung tipis. Garis rute dan lencana di atas foto terang akan
          // hilang tanpa ini.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x40000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),

          PratinjauRute(
            titik: trip.previewPath,
            tinggi: _tinggi,
            warna: Colors.white,
            latar: Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _KartuTrip extends StatelessWidget {
  const _KartuTrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return NapakPressable(
      onTap: () => context.push('/trip/${trip.id}'),
      skala: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: NapakColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _SampulTrip(trip: trip),
                if (trip.isRecording)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: _LencanaBerjalan(),
                  ),
                if (trip.mode == TripMode.group)
                  const Positioned(
                    top: 12,
                    left: 12,
                    child: _Lencana(ikon: Icons.group_rounded, teks: 'Bareng'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: text.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trip.startedAt == null
                        ? 'Belum berangkat'
                        : DateFormat(
                            "EEEE, d MMMM yyyy",
                            'id_ID',
                          ).format(trip.startedAt!),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Keping(
                        ikon: Icons.straighten_rounded,
                        teks: '${trip.distanceKm.toStringAsFixed(1)} km',
                        tebal: true,
                      ),
                      const SizedBox(width: 16),
                      _Keping(
                        ikon: Icons.timeline_rounded,
                        teks: '${trip.pointCount} jejak',
                      ),
                      const Spacer(),
                      Icon(
                        switch (trip.visibility) {
                          TripVisibility.private => Icons.lock_outline_rounded,
                          TripVisibility.link => Icons.link_rounded,
                          TripVisibility.public => Icons.public_rounded,
                        },
                        size: 15,
                        color: NapakColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NapakColors.base.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: NapakColors.deepAccent),
          const SizedBox(width: 6),
          Text(teks, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _LencanaBerjalan extends StatelessWidget {
  const _LencanaBerjalan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: NapakColors.base.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TitikBerdenyut(warna: NapakColors.deepAccent, ukuran: 6),
          const SizedBox(width: 2),
          Text('Berjalan', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Keping extends StatelessWidget {
  const _Keping({required this.ikon, required this.teks, this.tebal = false});

  final IconData ikon;
  final String teks;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 15, color: NapakColors.deepAccent),
        const SizedBox(width: 6),
        Text(
          teks,
          style: tebal
              ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
              : text.bodySmall,
        ),
      ],
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: NapakMotion.lambat,
            curve: NapakMotion.memantul,
            builder: (context, t, anak) =>
                Transform.scale(scale: t, child: anak),
            child: Icon(ikon, size: 44, color: NapakColors.primary),
          ),
          const SizedBox(height: 22),
          Text(judul, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(keterangan, style: text.bodySmall, textAlign: TextAlign.center),
          if (aksi != null) ...[const SizedBox(height: 26), aksi!],
        ],
      ),
    );
  }
}

/// "Tahun lalu hari ini."
///
/// Satu-satunya bagian Napak yang punya alasan dibuka di hari orang tidak
/// bepergian ke mana-mana. Jejak yang tidak hilang itu baru terasa artinya
/// kalau sesekali datang menghampiri sendiri — bukan cuma menunggu dicari.
///
/// Muncul sendiri hanya kalau memang ada, lalu hilang lagi besoknya. Tidak
/// ada ruang kosong yang menunggu diisi.
class _Kenangan extends ConsumerWidget {
  const _Kenangan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kenangan = ref.watch(kenanganProvider).value ?? const <Trip>[];

    return AnimatedSize(
      duration: NapakMotion.lambat,
      curve: NapakMotion.mengalir,
      child: kenangan.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, t) in kenangan.take(2).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MunculBertahap(
                        indeks: i,
                        child: _KartuKenangan(trip: t),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _KartuKenangan extends StatelessWidget {
  const _KartuKenangan({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tahunLalu = trip.startedAt == null
        ? null
        : DateTime.now().year - trip.startedAt!.year;

    return NapakPressable(
      // Langsung ke ceritanya, bukan ke halaman detail. Yang ingin dilakukan
      // orang saat kenangan menghampiri adalah membukanya kembali, bukan
      // membaca angkanya.
      onTap: () => context.push('/trip/${trip.id}/cerita'),
      skala: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: NapakColors.warmNeutral,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: PratinjauRute(
                titik: trip.previewPath,
                tinggi: 104,
                animasikan: false,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 13,
                          color: NapakColors.deepAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tahunLalu == null
                              ? 'Hari ini, dulu'
                              : tahunLalu == 1
                              ? 'Setahun lalu hari ini'
                              : '$tahunLalu tahun lalu hari ini',
                          style: text.labelMedium?.copyWith(
                            color: NapakColors.deepAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trip.title,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trip.distanceKm.toStringAsFixed(1)} km · buka ceritanya',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
