import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/theme/napak_tekstur.dart';
import '../../../core/widgets/napak_ekspedisi.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../../core/widgets/napak_skeleton.dart';
import '../../trips/data/trip_models.dart';

final recapProvider = FutureProvider.autoDispose.family<Recap, int>(
  (ref, tahun) => ref.watch(tripRepositoryProvider).recap(tahun),
);

/// Napak Tilas — ringkasan satu tahun perjalanan.
///
/// Disusun sebagai cerita, bukan dasbor: satu kalimat pembuka, lalu angka
/// besar yang berjalan naik, lalu nama-nama kota yang dilewati. Yang
/// dibagikan orang ke media sosial adalah ceritanya, bukan tabelnya.
///
/// Angkanya sengaja berjalan naik alih-alih muncul begitu saja. Angka yang
/// langsung jadi terbaca sebagai data; angka yang naik terbaca sebagai
/// sesuatu yang dikumpulkan — dan memang itu yang terjadi sepanjang tahun.
class RecapPage extends ConsumerStatefulWidget {
  const RecapPage({this.tahun, super.key});

  final int? tahun;

  @override
  ConsumerState<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends ConsumerState<RecapPage> {
  late int _tahun = widget.tahun ?? DateTime.now().year;
  bool _menghitungUlang = false;

  Future<void> _hitungUlang() async {
    setState(() => _menghitungUlang = true);
    try {
      await ref.read(tripRepositoryProvider).refreshRecap(_tahun);
      ref.invalidate(recapProvider(_tahun));
    } finally {
      if (mounted) setState(() => _menghitungUlang = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = ref.watch(recapProvider(_tahun));
    final text = Theme.of(context).textTheme;
    final tahunIni = DateTime.now().year;

    return Scaffold(
      backgroundColor: NapakColors.malam,
      body: PendengarGulir(
        builder: (geser) => LatarEkspedisi(
          gunung: true,
          geser: geser,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LabelKapital(
                                'Setahun ke belakang',
                                warna: NapakColors.emberRedup,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Napak Tilas',
                                style: text.displaySmall?.copyWith(
                                  color: NapakColors.base,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Menyusuri kembali setahun yang sudah lewat.',
                                style: text.bodyMedium?.copyWith(
                                  color: NapakColors.base.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hitung ulang',
                          onPressed: _menghitungUlang ? null : _hitungUlang,
                          color: NapakColors.emberRedup,
                          icon: AnimatedRotation(
                            // Ikonnya ikut berputar selagi menghitung — satu
                            // isyarat, tanpa perlu menumpuk spinner terpisah.
                            turns: _menghitungUlang ? 1 : 0,
                            duration: const Duration(milliseconds: 900),
                            child: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: _PemilihTahun(
                    tahun: _tahun,
                    tahunTerbaru: tahunIni,
                    onPilih: (t) => setState(() => _tahun = t),
                  ),
                ),
              ),

              recap.when(
                loading: () => const SliverToBoxAdapter(child: _MemuatRecap()),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: NapakColors.base.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                // Key berdasarkan tahun: berganti tahun berarti seluruh isinya
                // dibangun ulang, jadi angkanya berjalan naik lagi dari nol.
                data: (data) => SliverToBoxAdapter(
                  key: ValueKey(data.year),
                  child: _IsiRecap(recap: data),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IsiRecap extends StatelessWidget {
  const _IsiRecap({required this.recap});

  final Recap recap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MunculBertahap(
            indeks: 0,
            child: Text(
              recap.caption,
              style: text.headlineSmall?.copyWith(
                height: 1.45,
                color: NapakColors.base,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const MunculBertahap(indeks: 0, child: _PintuNusantara()),
          const SizedBox(height: 30),

          MunculBertahap(
            indeks: 1,
            child: Row(
              children: [
                _Kartu(
                  nilai: recap.totalDistanceKm,
                  desimal: 1,
                  satuan: 'km',
                  label: 'Ditempuh',
                  utama: true,
                ),
                const SizedBox(width: 12),
                _Kartu(
                  nilai: recap.totalTrips.toDouble(),
                  satuan: '',
                  label: 'Perjalanan',
                ),
                const SizedBox(width: 12),
                _Kartu(
                  nilai: recap.totalCities.toDouble(),
                  satuan: '',
                  label: 'Kota',
                ),
              ],
            ),
          ),

          if (recap.longestTripTitle != null) ...[
            const SizedBox(height: 28),
            MunculBertahap(
              indeks: 2,
              child: _TripTerjauh(
                judul: recap.longestTripTitle!,
                km: recap.longestTripKm ?? 0,
              ),
            ),
          ],

          if (recap.cities.isNotEmpty) ...[
            const SizedBox(height: 36),
            MunculBertahap(
              indeks: 3,
              child: const LabelKapital(
                'Kota yang kamu lewati',
                warna: NapakColors.emberRedup,
                ukuran: 12,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, kota) in recap.cities.indexed)
                  // Kota-kotanya muncul satu per satu, seperti dihitung ulang
                  // satu per satu di kepala.
                  MunculBertahap(
                    indeks: 4 + i,
                    jarakGeser: 8,
                    child: _KepingKota(nama: kota),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            MunculBertahap(
              indeks: 5 + recap.cities.length,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: NapakColors.base.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dihitung di dalam Napak sendiri, tanpa mengirim '
                      'koordinatmu ke layanan peta mana pun.',
                      style: text.bodySmall?.copyWith(
                        color: NapakColors.base.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
          MunculBertahap(
            indeks: 6 + recap.cities.length,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: NapakColors.ember,
                foregroundColor: NapakColors.malam,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: '${recap.caption}\n\n— Napak',
                  subject: 'Napak Tilas ${recap.year}',
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: const Text('Bagikan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PemilihTahun extends StatelessWidget {
  const _PemilihTahun({
    required this.tahun,
    required this.tahunTerbaru,
    required this.onPilih,
  });

  final int tahun;
  final int tahunTerbaru;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    // Lima tahun ke belakang sudah cukup. Napak baru seumur jagung.
    final pilihan = [for (var t = tahunTerbaru; t > tahunTerbaru - 5; t--) t];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pilihan.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = pilihan[i];
          final terpilih = t == tahun;

          return NapakPressable(
            onTap: () => onPilih(t),
            skala: 0.94,
            child: AnimatedContainer(
              duration: NapakMotion.cepat,
              curve: NapakMotion.mengalir,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: terpilih
                    ? NapakColors.ember
                    : NapakColors.malamNaik.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: terpilih ? NapakColors.ember : NapakColors.kontur,
                ),
              ),
              child: AnimatedDefaultTextStyle(
                duration: NapakMotion.cepat,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: terpilih
                      ? NapakColors.malam
                      : NapakColors.base.withValues(alpha: 0.6),
                  fontWeight: terpilih ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: Text('$t'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.nilai,
    required this.satuan,
    required this.label,
    this.desimal = 0,
    this.utama = false,
  });

  final double nilai;
  final String satuan;
  final String label;
  final int desimal;

  /// Angka utama dapat latar biru penuh — satu titik berat per layar,
  /// supaya mata tahu harus mendarat di mana.
  final bool utama;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Expanded(
      flex: utama ? 4 : 3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: utama
              ? NapakColors.ember.withValues(alpha: 0.16)
              : NapakColors.malamNaik.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: utama ? NapakColors.ember : NapakColors.kontur,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            FittedBox(
              child: Odometer(
                nilai: nilai,
                desimal: desimal,
                satuan: satuan.isEmpty ? null : satuan.toUpperCase(),
                gaya: (utama ? text.headlineMedium : text.headlineSmall)
                    ?.copyWith(
                      color: utama ? NapakColors.ember : NapakColors.base,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            LabelKapital(
              label,
              warna: NapakColors.base.withValues(alpha: 0.55),
              ukuran: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripTerjauh extends StatelessWidget {
  const _TripTerjauh({required this.judul, required this.km});

  final String judul;
  final double km;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NapakColors.malamNaik.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NapakColors.kontur),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: NapakColors.ember.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flag_outlined,
              size: 21,
              color: NapakColors.ember,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelKapital('Yang paling jauh', ukuran: 10),
                const SizedBox(height: 3),
                Text(
                  judul,
                  style: text.titleMedium?.copyWith(color: NapakColors.base),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${km.toStringAsFixed(1)} km',
                  style: text.bodySmall?.copyWith(
                    color: NapakColors.emberRedup,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KepingKota extends StatelessWidget {
  const _KepingKota({required this.nama});

  final String nama;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: NapakColors.malamNaik.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NapakColors.kontur),
      ),
      child: Text(
        nama,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: NapakColors.base.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _MemuatRecap extends StatelessWidget {
  const _MemuatRecap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 34, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NapakSkeleton.teks(lebar: 260, gelap: true),
          SizedBox(height: 10),
          NapakSkeleton.teks(lebar: 180, gelap: true),
          SizedBox(height: 34),
          NapakSkeleton(tinggi: 104, radius: 16, gelap: true),
          SizedBox(height: 28),
          NapakSkeleton(tinggi: 84, radius: 16, gelap: true),
        ],
      ),
    );
  }
}

/// Pintu ke Jejak Nusantara: peta seumur hidup, bukan per tahun.
class _PintuNusantara extends StatelessWidget {
  const _PintuNusantara();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return NapakPressable(
      onTap: () => context.push('/jejak-nusantara'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NapakColors.ember.withValues(alpha: 0.2),
              NapakColors.malamNaik.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NapakColors.ember.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: NapakColors.ember),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jejak Nusantara',
                    style: text.titleMedium?.copyWith(
                      color: NapakColors.base,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Lihat kota-kota yang pernah kamu lewati menyala di peta.',
                    style: text.bodySmall?.copyWith(
                      color: NapakColors.base.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: NapakColors.emberRedup,
            ),
          ],
        ),
      ),
    );
  }
}
