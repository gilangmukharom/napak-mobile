import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
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
      backgroundColor: NapakColors.base,
      body: CustomScrollView(
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
                          Text('Napak Tilas', style: text.displaySmall),
                          const SizedBox(height: 6),
                          Text(
                            'Menyusuri kembali setahun yang sudah lewat.',
                            style: text.bodyMedium?.copyWith(
                              color: NapakColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hitung ulang',
                      onPressed: _menghitungUlang ? null : _hitungUlang,
                      color: NapakColors.deepAccent,
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
                  style: text.bodyMedium,
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
              style: text.headlineSmall?.copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 34),

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
              child: Text('Kota yang kamu lewati', style: text.titleLarge),
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
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: NapakColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dihitung di dalam Napak sendiri, tanpa mengirim '
                      'koordinatmu ke layanan peta mana pun.',
                      style: text.bodySmall,
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
                color: terpilih ? NapakColors.deepAccent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: terpilih
                      ? NapakColors.deepAccent
                      : NapakColors.divider,
                ),
              ),
              child: AnimatedDefaultTextStyle(
                duration: NapakMotion.cepat,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: terpilih
                      ? NapakColors.textOnDeep
                      : NapakColors.textSecondary,
                  fontWeight: terpilih ? FontWeight.w600 : FontWeight.w400,
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
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: utama ? NapakColors.primary : NapakColors.softSky,
          borderRadius: BorderRadius.circular(20),
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
                    gaya: utama ? text.headlineMedium : text.headlineSmall,
                  ),
                  if (satuan.isNotEmpty) Text(' $satuan', style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: text.bodySmall, textAlign: TextAlign.center),
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
        color: NapakColors.warmNeutral,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.flag_outlined,
              size: 21,
              color: NapakColors.deepAccent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yang paling jauh', style: text.bodySmall),
                const SizedBox(height: 3),
                Text(
                  judul,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('${km.toStringAsFixed(1)} km', style: text.bodySmall),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NapakColors.divider),
      ),
      child: Text(nama, style: Theme.of(context).textTheme.bodySmall),
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
          NapakSkeleton.teks(lebar: 260),
          SizedBox(height: 10),
          NapakSkeleton.teks(lebar: 180),
          SizedBox(height: 34),
          NapakSkeleton(tinggi: 104, radius: 20),
          SizedBox(height: 28),
          NapakSkeleton(tinggi: 84, radius: 20),
        ],
      ),
    );
  }
}
