import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../data/navigasi_data.dart';

/// Pilih tujuan perjalanan.
///
/// Dicari dari tabel kota Tourvella sendiri — 188 kota, di-host sendiri.
/// "Ke Jogja" yang diketik orang tidak pernah dikirim ke layanan pencarian
/// tempat mana pun, sama seperti "SPBU terdekat".
class PilihTujuanSheet extends ConsumerStatefulWidget {
  const PilihTujuanSheet({super.key});

  static Future<Tujuan?> tampilkan(BuildContext context) {
    return showModalBottomSheet<Tujuan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TourvellaColors.base,
      builder: (_) => const PilihTujuanSheet(),
    );
  }

  @override
  ConsumerState<PilihTujuanSheet> createState() => _PilihTujuanSheetState();
}

class _PilihTujuanSheetState extends ConsumerState<PilihTujuanSheet> {
  final _kata = TextEditingController();
  Timer? _tunggu;
  List<Tujuan> _hasil = const [];
  bool _mencari = false;

  @override
  void dispose() {
    _tunggu?.cancel();
    _kata.dispose();
    super.dispose();
  }

  void _ketik(String kata) {
    _tunggu?.cancel();
    if (kata.trim().length < 2) {
      setState(() => _hasil = const []);
      return;
    }
    // Menunggu orangnya berhenti mengetik dulu, bukan menembak server tiap
    // huruf.
    _tunggu = Timer(TourvellaMotion.sedang, () => _cari(kata));
  }

  Future<void> _cari(String kata) async {
    setState(() => _mencari = true);
    try {
      final hasil = await ref.read(navigasiRepositoryProvider).cari(kata);
      if (mounted) setState(() => _hasil = hasil);
    } catch (_) {
      if (mounted) setState(() => _hasil = const []);
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: TourvellaColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mau ke mana?', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Tourvella akan memandumu dengan suara. Pencariannya '
                    'memakai daftar kota Tourvella sendiri.',
                    style: text.bodySmall?.copyWith(
                      color: TourvellaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: TextField(
                controller: _kata,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Kota tujuan, misalnya Yogyakarta',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _mencari
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _ketik,
                onSubmitted: _cari,
              ),
            ),
            const Divider(height: 1, color: TourvellaColors.divider),
            Expanded(
              child: _hasil.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _kata.text.trim().length < 2
                              ? 'Ketik nama kotanya.'
                              : 'Belum ketemu kota itu.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: TourvellaColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _hasil.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 68,
                        color: TourvellaColors.divider,
                      ),
                      itemBuilder: (_, i) {
                        final t = _hasil[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: TourvellaColors.softSky,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: TourvellaColors.deepAccent,
                            ),
                          ),
                          title: Text(t.nama),
                          subtitle: Text(t.provinsi),
                          onTap: () => Navigator.of(context).pop(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
