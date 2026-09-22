import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../recording/application/recording_controller.dart';
import '../../trips/data/trip_models.dart';

/// Tab "Kamu" — profil, janji privasi, dan pintu keluar.
///
/// Janji privasi ditaruh di sini, bukan disembunyikan di dokumen terpisah
/// yang tidak pernah dibuka siapa pun. Kalau Tourvella memang menjadikan privasi
/// sebagai fondasi, orangnya berhak membaca janji itu di tempat yang wajar
/// dilihat — bukan di halaman syarat dan ketentuan.
class PengaturanPage extends ConsumerWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final nama = ref.watch(savedNameProvider).value;
    final trips = ref.watch(tripListProvider).value ?? const <Trip>[];

    final totalKm = trips.fold<double>(0, (jml, t) => jml + t.distanceKm);

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      // Sekarang dibuka dari menu di profil, jadi punya jalan kembali.
      appBar: const BilahEkspedisi(
        judul: 'Pengaturan & privasi',
        keterangan: 'Jejakmu, kendalimu',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
        children: [
          MunculBertahap(
            indeks: 0,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: TourvellaColors.kanvasMalam,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TourvellaColors.kontur),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: KonturTopografi(
                        opasitas: 0.2,
                        jumlahGaris: 4,
                        benih: 23,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 54,
                            width: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TourvellaColors.ember.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TourvellaColors.ember),
                            ),
                            child: Text(
                              (nama ?? 'P').characters.first.toUpperCase(),
                              style: text.headlineSmall?.copyWith(
                                color: TourvellaColors.ember,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nama ?? 'Penjejak',
                                  style: text.titleLarge?.copyWith(
                                    color: TourvellaColors.base,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                const LabelKapital(
                                  'Akun Tourvella',
                                  warna: TourvellaColors.emberRedup,
                                  ukuran: 9,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          _AngkaRingkas(
                            nilai: totalKm,
                            desimal: 1,
                            satuan: 'km',
                            label: 'Total ditempuh',
                          ),
                          const SizedBox(width: 24),
                          _AngkaRingkas(
                            nilai: trips.length.toDouble(),
                            satuan: '',
                            label: 'Perjalanan',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),
          const MunculBertahap(indeks: 1, child: _PintuSosial()),

          const SizedBox(height: 34),
          MunculBertahap(
            indeks: 1,
            child: const LabelKapital(
              'Jejakmu, kendalimu',
              warna: TourvellaColors.deepAccent,
              ukuran: 12,
            ),
          ),
          const SizedBox(height: 14),

          const MunculBertahap(
            indeks: 2,
            child: _ButirPrivasi(
              ikon: Icons.lock_outline_rounded,
              judul: 'Semua perjalanan tertutup sejak awal',
              keterangan:
                  'Tidak ada yang bisa melihat jejakmu sampai kamu sendiri '
                  'yang membukanya.',
            ),
          ),
          const MunculBertahap(
            indeks: 3,
            child: _ButirPrivasi(
              ikon: Icons.enhanced_encryption_outlined,
              judul: 'Koordinatmu tersimpan terenkripsi',
              keterangan:
                  'Titik persis perjalananmu diacak sebelum disimpan. Yang '
                  'bisa dibaca langsung dari database hanya perkiraan kasar.',
            ),
          ),
          const MunculBertahap(
            indeks: 4,
            child: _ButirPrivasi(
              ikon: Icons.visibility_off_outlined,
              judul: 'Tamu hanya melihat bentuk rutenya',
              keterangan:
                  'Saat sebuah perjalanan kamu bagikan, orang lain melihat '
                  'garis besarnya saja — bukan titik persis, bukan catatanmu.',
            ),
          ),
          const MunculBertahap(
            indeks: 5,
            child: _ButirPrivasi(
              ikon: Icons.delete_outline_rounded,
              judul: 'Hapus berarti benar-benar hilang',
              keterangan:
                  'Termasuk video yang sudah dibuat. Tidak disembunyikan, '
                  'tidak diarsipkan.',
            ),
          ),

          const SizedBox(height: 26),
          MunculBertahap(
            indeks: 6,
            child: OutlinedButton.icon(
              onPressed: () => _keluar(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Keluar'),
            ),
          ),
          const SizedBox(height: 10),
          MunculBertahap(
            indeks: 7,
            child: TextButton(
              onPressed: () => _hapusAkun(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: TourvellaColors.attention,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Hapus akun dan semua jejak'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Menghapus akun berarti menghapus seluruh perjalananmu secara '
            'permanen. Tidak ada arsip, tidak ada masa tenggang.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _keluar(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingPointCountProvider).value ?? 0;

    if (pending > 0) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: TourvellaColors.base,
          title: const Text('Masih ada jejak yang belum terkirim'),
          content: Text(
            '$pending jejak masih menunggu sinyal. Kalau keluar sekarang, '
            'jejak itu ikut terhapus dari HP ini.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Tunggu dulu'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tetap keluar'),
            ),
          ],
        ),
      );
      if (lanjut != true) return;
    }

    await ref.read(authRepositoryProvider).signOut();
    await ref.read(localDatabaseProvider).wipe();
    ref.invalidate(sessionProvider);
    ref.invalidate(savedNameProvider);
    ref.invalidate(tripListProvider);

    if (!context.mounted) return;
    context.go('/masuk');
  }

  Future<void> _hapusAkun(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TourvellaColors.base,
        title: const Text('Hapus akun?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Semua perjalanan, jejak, catatan, foto, dan video dihapus '
              'sepenuhnya. Ini tidak bisa dibatalkan.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
            Text(
              'Ketik nomor HP-mu untuk memastikan:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(hintText: '0812 3456 7890'),
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
            child: const Text('Hapus selamanya'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    try {
      final pesan = await ref
          .read(authRepositoryProvider)
          .deleteAccount(controller.text);
      await ref.read(localDatabaseProvider).wipe();
      ref.invalidate(sessionProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesan)));
      context.go('/masuk');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _AngkaRingkas extends StatelessWidget {
  const _AngkaRingkas({
    required this.nilai,
    required this.satuan,
    required this.label,
    this.desimal = 0,
  });

  final double nilai;
  final String satuan;
  final String label;
  final int desimal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Odometer(
              nilai: nilai,
              desimal: desimal,
              satuan: satuan.isEmpty ? null : satuan.toUpperCase(),
              gaya: text.headlineSmall?.copyWith(
                color: TourvellaColors.ember,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LabelKapital(
          label,
          warna: TourvellaColors.base.withValues(alpha: 0.55),
          ukuran: 9,
        ),
      ],
    );
  }
}

class _ButirPrivasi extends StatelessWidget {
  const _ButirPrivasi({
    required this.ikon,
    required this.judul,
    required this.keterangan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: TourvellaColors.softSky,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, size: 18, color: TourvellaColors.deepAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: text.bodyMedium),
                const SizedBox(height: 3),
                Text(keterangan, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintu ke teman, kotak pos, dan Jejak Nusantara.
class _PintuSosial extends StatelessWidget {
  const _PintuSosial();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pintu(
            ikon: Icons.group_outlined,
            label: 'Teman',
            onTap: () => context.push('/teman'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Pintu(
            ikon: Icons.local_post_office_outlined,
            label: 'Kotak pos',
            onTap: () => context.push('/kartu-pos'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Pintu(
            ikon: Icons.auto_awesome_outlined,
            label: 'Nusantara',
            onTap: () => context.push('/jejak-nusantara'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Pintu(
            ikon: Icons.download_for_offline_outlined,
            label: 'Peta offline',
            onTap: () => context.push('/peta-offline'),
          ),
        ),
      ],
    );
  }
}

class _Pintu extends StatelessWidget {
  const _Pintu({required this.ikon, required this.label, required this.onTap});

  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: TourvellaColors.softSky,
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, color: TourvellaColors.deepAccent),
              ),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
