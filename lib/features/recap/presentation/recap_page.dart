import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../trips/data/trip_models.dart';

final recapProvider = FutureProvider.autoDispose.family<Recap, int>(
  (ref, tahun) => ref.watch(tripRepositoryProvider).recap(tahun),
);

/// Ringkasan satu tahun perjalanan.
///
/// Disusun sebagai cerita, bukan dasbor: satu kalimat pembuka, lalu angka
/// besar yang mudah dibaca sekilas, lalu nama-nama kota yang dilewati. Yang
/// dibagikan orang ke media sosial adalah ceritanya, bukan tabelnya.
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
    final tahunIni = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Napak Tilas'),
        actions: [
          IconButton(
            tooltip: 'Hitung ulang',
            icon: _menghitungUlang
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            color: NapakColors.deepAccent,
            onPressed: _menghitungUlang ? null : _hitungUlang,
          ),
        ],
      ),
      body: recap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            _PemilihTahun(
              tahun: _tahun,
              tahunTerbaru: tahunIni,
              onPilih: (t) => setState(() => _tahun = t),
            ),
            const SizedBox(height: 28),
            Text(
              data.caption,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _AngkaBesar(
                  nilai: _formatKm(data.totalDistanceKm),
                  satuan: 'km',
                  label: 'Ditempuh',
                ),
                const SizedBox(width: 12),
                _AngkaBesar(
                  nilai: '${data.totalTrips}',
                  satuan: '',
                  label: data.totalTrips == 1 ? 'Perjalanan' : 'Perjalanan',
                ),
                const SizedBox(width: 12),
                _AngkaBesar(
                  nilai: '${data.totalCities}',
                  satuan: '',
                  label: 'Kota',
                ),
              ],
            ),
            if (data.longestTripTitle != null) ...[
              const SizedBox(height: 28),
              _TripTerjauh(
                judul: data.longestTripTitle!,
                km: data.longestTripKm ?? 0,
              ),
            ],
            if (data.cities.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Kota yang kamu lewati',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kota in data.cities) _KepingKota(nama: kota),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Dihitung di dalam Napak sendiri, tanpa mengirim koordinatmu '
                'ke layanan peta mana pun.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: '${data.caption}\n\n— Napak',
                  subject: 'Napak Tilas $_tahun',
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: const Text('Bagikan'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatKm(double km) =>
      NumberFormat.decimalPatternDigits(locale: 'id_ID', decimalDigits: 1)
          .format(km);
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
    final pilihan = [
      for (var t = tahunTerbaru; t > tahunTerbaru - 5; t--) t,
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pilihan.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = pilihan[i];
          final terpilih = t == tahun;
          return GestureDetector(
            onTap: () => onPilih(t),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: terpilih ? NapakColors.primary : NapakColors.softSky,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$t',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: terpilih ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AngkaBesar extends StatelessWidget {
  const _AngkaBesar({
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text.rich(
                TextSpan(
                  text: nilai,
                  style: text.headlineSmall,
                  children: [
                    if (satuan.isNotEmpty)
                      TextSpan(text: ' $satuan', style: text.bodySmall),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.flag_outlined,
            size: 22,
            color: NapakColors.deepAccent,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yang paling jauh', style: text.bodySmall),
                const SizedBox(height: 4),
                Text(judul, style: text.titleMedium),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: NapakColors.softSky,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(nama, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
