import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../data/peta_offline.dart';

/// Peta offline: wilayah yang sudah dibawa, dan yang bisa diunduh.
class PetaOfflinePage extends ConsumerStatefulWidget {
  const PetaOfflinePage({super.key});

  @override
  ConsumerState<PetaOfflinePage> createState() => _PetaOfflinePageState();
}

class _PetaOfflinePageState extends ConsumerState<PetaOfflinePage> {
  /// Unduhan yang sedang berjalan, dikunci nama wilayah.
  final _berjalan = <String, KemajuanUnduh>{};

  Future<void> _mulai(WilayahSiap w) async {
    final pilihan = await showModalBottomSheet<Kerincian>(
      context: context,
      backgroundColor: NapakColors.base,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PilihKerincian(wilayah: w),
    );
    if (pilihan == null || !mounted) return;

    final layanan = ref.read(petaOfflineServiceProvider);
    PerkiraanUnduhan? perkiraan;
    try {
      perkiraan = await layanan.perkiraan(w.kotak, pilihan);
    } catch (_) {}

    HapticFeedback.mediumImpact();
    setState(() => _berjalan[w.nama] = const SedangMengunduh(0, 0, 0));

    await for (final k in layanan.unduh(
      nama: w.nama,
      kotak: w.kotak,
      kerincian: pilihan,
      perkiraanByte: perkiraan?.byte,
    )) {
      if (!mounted) return;
      setState(() => _berjalan[w.nama] = k);

      if (k is UnduhanSelesai) {
        HapticFeedback.heavyImpact();
        ref.invalidate(daftarWilayahOfflineProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${w.nama} siap dipakai tanpa sinyal, '
              'beserta ${k.wilayah.jumlahLayanan ?? 0} SPBU dan bengkel.',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) setState(() => _berjalan.remove(w.nama));
      } else if (k is UnduhanGagal) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(k.pesan)));
        setState(() => _berjalan.remove(w.nama));
      }
    }
  }

  Future<void> _hapus(WilayahOffline w) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${w.nama}?'),
        content: const Text(
          'Peta dan data SPBU/bengkel wilayah ini dibuang dari HP. '
          'Bisa diunduh lagi kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await ref.read(petaOfflineServiceProvider).hapus(w.id);
    ref.invalidate(daftarWilayahOfflineProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tersimpan = ref.watch(daftarWilayahOfflineProvider);
    final text = Theme.of(context).textTheme;
    final namaTersimpan = {
      for (final w in tersimpan.value ?? const <WilayahOffline>[]) w.nama,
    };

    return Scaffold(
      backgroundColor: NapakColors.base,
      appBar: AppBar(title: const Text('Peta offline')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          const _Pembuka(),
          const SizedBox(height: 24),

          // --- Yang sudah dibawa ---
          ...tersimpan.when(
            loading: () => [const LinearProgressIndicator()],
            error: (e, _) => [Text(e.toString())],
            data: (daftar) => daftar.isEmpty
                ? <Widget>[]
                : [
                    Text('Sudah di HP', style: text.titleMedium),
                    const SizedBox(height: 10),
                    for (var i = 0; i < daftar.length; i++)
                      _KartuTersimpan(
                            w: daftar[i],
                            onHapus: () => _hapus(daftar[i]),
                          )
                          .animate(delay: (50 * i).ms)
                          .fadeIn(duration: NapakMotion.sedang)
                          .slideX(begin: 0.05),
                    const SizedBox(height: 24),
                  ],
          ),

          Text('Unduh wilayah', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Unduh selagi ada Wi-Fi. Petanya dari server Napak sendiri — '
            'tidak ada penyedia peta luar yang tahu wilayah mana yang kamu bawa.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < wilayahSiap.length; i++)
            _KartuWilayah(
                  w: wilayahSiap[i],
                  sudahAda: namaTersimpan.contains(wilayahSiap[i].nama),
                  kemajuan: _berjalan[wilayahSiap[i].nama],
                  onUnduh: () => _mulai(wilayahSiap[i]),
                )
                .animate(delay: (40 * i).ms)
                .fadeIn(duration: NapakMotion.sedang)
                .slideY(begin: 0.08, curve: NapakMotion.mengalir),
        ],
      ),
    );
  }
}

class _Pembuka extends StatelessWidget {
  const _Pembuka();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: NapakColors.routeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tetap tahu jalan\nwalau sinyal hilang',
                  style: text.titleLarge?.copyWith(
                    color: NapakColors.textOnDeep,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jalan sampai gang, nama jalan, SPBU dan bengkel — '
                  'tersimpan di HP.',
                  style: text.bodySmall?.copyWith(
                    color: NapakColors.textOnDeep.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Sinyal yang memudar lalu digantikan peta — bahasa gambar yang
          // langsung terbaca tanpa kalimat.
          const Icon(
                Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                size: 40,
                color: NapakColors.textOnDeep,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 1, end: 0.35, duration: 1400.ms)
              .scaleXY(begin: 1, end: 0.9, duration: 1400.ms),
        ],
      ),
    ).animate().fadeIn().scaleXY(begin: 0.97, curve: NapakMotion.mengalir);
  }
}

class _KartuWilayah extends StatelessWidget {
  const _KartuWilayah({
    required this.w,
    required this.sudahAda,
    required this.kemajuan,
    required this.onUnduh,
  });

  final WilayahSiap w;
  final bool sudahAda;
  final KemajuanUnduh? kemajuan;
  final VoidCallback onUnduh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final k = kemajuan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NapakPressable(
        onTap: sudahAda || k != null ? null : onUnduh,
        skala: 0.985,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _MiniKotak(kotak: w.kotak),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.nama, style: text.titleSmall),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: NapakMotion.cepat,
                      child: Text(
                        switch (k) {
                          SedangMengunduh(:final selesai, :final total)
                              when total > 0 =>
                            'Mengunduh $selesai dari $total bagian…',
                          SedangMengunduh() => 'Menyiapkan…',
                          MengunduhLayanan() => 'Menyimpan SPBU & bengkel…',
                          UnduhanSelesai() => 'Selesai',
                          _ => sudahAda ? 'Sudah di HP' : w.keterangan,
                        },
                        key: ValueKey(k.runtimeType),
                        style: text.bodySmall,
                      ),
                    ),
                    if (k is SedangMengunduh) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: k.porsi),
                          duration: NapakMotion.sedang,
                          builder: (context, t, _) => LinearProgressIndicator(
                            value: t == 0 ? null : t,
                            minHeight: 5,
                            backgroundColor: NapakColors.softSky,
                            valueColor: const AlwaysStoppedAnimation(
                              NapakColors.deepAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: NapakMotion.sedang,
                transitionBuilder: (anak, a) =>
                    ScaleTransition(scale: a, child: anak),
                child: switch (k) {
                  SedangMengunduh(:final porsi) => Text(
                    '${(porsi * 100).round()}%',
                    key: const ValueKey('persen'),
                    style: text.labelLarge?.copyWith(
                      color: NapakColors.deepAccent,
                    ),
                  ),
                  MengunduhLayanan() => const SizedBox(
                    key: ValueKey('layanan'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  UnduhanSelesai() => const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey('ok'),
                    color: NapakColors.affirm,
                  ),
                  _ => Icon(
                    sudahAda
                        ? Icons.offline_pin_rounded
                        : Icons.download_for_offline_outlined,
                    key: ValueKey(sudahAda),
                    color: sudahAda
                        ? NapakColors.affirm
                        : NapakColors.deepAccent,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bentuk kotak wilayahnya, digambar kecil — lebar atau jangkung, sekadar
/// memberi rasa seberapa luas yang akan dibawa.
class _MiniKotak extends StatelessWidget {
  const _MiniKotak({required this.kotak});

  final Kotak kotak;

  @override
  Widget build(BuildContext context) {
    final lebar = kotak.e - kotak.w;
    final tinggi = kotak.n - kotak.s;
    final skala = 34 / math.max(lebar, tinggi);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: NapakColors.softSky,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Container(
        width: math.max(lebar * skala, 8),
        height: math.max(tinggi * skala, 8),
        decoration: BoxDecoration(
          border: Border.all(color: NapakColors.deepAccent, width: 1.6),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _KartuTersimpan extends StatelessWidget {
  const _KartuTersimpan({required this.w, required this.onHapus});

  final WilayahOffline w;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ukuran = w.ukuranByte == null
        ? null
        : PerkiraanUnduhan(tile: 0, byte: w.ukuranByte!).teksUkuran;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: NapakColors.softSky.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            w.cocokDenganServer
                ? Icons.offline_pin_rounded
                : Icons.sync_problem_rounded,
            color: w.cocokDenganServer
                ? NapakColors.deepAccent
                : NapakColors.attention,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.nama, style: text.titleSmall),
                Text(
                  w.cocokDenganServer
                      ? [
                          w.zoomMaks >= 14 ? 'Lengkap' : 'Hemat',
                          ?ukuran,
                          if (w.jumlahLayanan != null)
                            '${w.jumlahLayanan} SPBU & bengkel',
                        ].join(' · ')
                      // Alamat server uji coba berganti tiap tunnel
                      // dijalankan ulang; peta yang diunduh lewat alamat lama
                      // tidak lagi dikenali. Dikatakan terus terang.
                      : 'Diunduh dari alamat server lama. Hapus dan unduh '
                            'ulang supaya terpakai.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: onHapus,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _PilihKerincian extends ConsumerStatefulWidget {
  const _PilihKerincian({required this.wilayah});

  final WilayahSiap wilayah;

  @override
  ConsumerState<_PilihKerincian> createState() => _PilihKerincianState();
}

class _PilihKerincianState extends ConsumerState<_PilihKerincian> {
  final _perkiraan = <Kerincian, PerkiraanUnduhan?>{};
  Kerincian _pilih = Kerincian.lengkap;
  String? _galat;

  @override
  void initState() {
    super.initState();
    unawaited(_hitung());
  }

  Future<void> _hitung() async {
    final layanan = ref.read(petaOfflineServiceProvider);
    try {
      if (!await layanan.petaServerTersedia()) {
        setState(
          () => _galat =
              'Peta Indonesia belum terpasang di server. '
              'Jalankan pembangunan peta dulu (lihat CLAUDE.md).',
        );
        return;
      }
      for (final k in Kerincian.values) {
        final p = await layanan.perkiraan(widget.wilayah.kotak, k);
        if (mounted) setState(() => _perkiraan[k] = p);
      }
    } catch (e) {
      if (mounted) setState(() => _galat = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NapakColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.wilayah.nama, style: text.titleLarge),
            Text(widget.wilayah.keterangan, style: text.bodySmall),
            const SizedBox(height: 16),
            if (_galat != null)
              KosongHangat(
                ikon: Icons.map_outlined,
                judul: 'Belum bisa diunduh',
                isi: _galat!,
              )
            else
              for (final k in Kerincian.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NapakPressable(
                    onTap: () => setState(() => _pilih = k),
                    skala: 0.98,
                    child: AnimatedContainer(
                      duration: NapakMotion.cepat,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _pilih == k ? NapakColors.softSky : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _pilih == k
                              ? NapakColors.deepAccent
                              : NapakColors.divider,
                          width: _pilih == k ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(k.label, style: text.titleSmall),
                                Text(k.keterangan, style: text.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: NapakMotion.cepat,
                            child: _perkiraan[k] == null
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '± ${_perkiraan[k]!.teksUkuran}',
                                    style: text.labelLarge?.copyWith(
                                      color: NapakColors.deepAccent,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _galat != null
                    ? null
                    : () => Navigator.of(context).pop(_pilih),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Unduh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
