import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../recording/application/recording_controller.dart';

class PengaturanPage extends ConsumerWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final nama = ref.watch(savedNameProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NapakColors.softSky,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: NapakColors.primary,
                  child: Text(
                    (nama ?? 'P').characters.first.toUpperCase(),
                    style: text.titleLarge,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nama ?? 'Penjejak', style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text('Akun Napak', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Jejakmu, kendalimu', style: text.titleLarge),
          const SizedBox(height: 12),
          const _ButirPrivasi(
            ikon: Icons.lock_outline_rounded,
            judul: 'Semua perjalanan tertutup sejak awal',
            keterangan:
                'Tidak ada yang bisa melihat jejakmu sampai kamu sendiri '
                'yang membukanya.',
          ),
          const _ButirPrivasi(
            ikon: Icons.enhanced_encryption_outlined,
            judul: 'Koordinatmu tersimpan terenkripsi',
            keterangan:
                'Titik persis perjalananmu diacak sebelum disimpan. Yang bisa '
                'dibaca langsung dari database hanya perkiraan kasar.',
          ),
          const _ButirPrivasi(
            ikon: Icons.visibility_off_outlined,
            judul: 'Tamu hanya melihat bentuk rutenya',
            keterangan:
                'Saat sebuah perjalanan kamu bagikan, orang lain melihat '
                'garis besarnya saja — bukan titik persis dan bukan catatanmu.',
          ),
          const SizedBox(height: 36),
          OutlinedButton.icon(
            onPressed: () => _keluar(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Keluar'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _hapusAkun(context, ref),
            style: TextButton.styleFrom(
              foregroundColor: NapakColors.attention,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Hapus akun dan semua jejak'),
          ),
          const SizedBox(height: 8),
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
          backgroundColor: NapakColors.base,
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
        backgroundColor: NapakColors.base,
        title: const Text('Hapus akun?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Semua perjalanan, jejak, catatan, dan fotomu dihapus '
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
              backgroundColor: NapakColors.attention,
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
          Icon(ikon, size: 20, color: NapakColors.deepAccent),
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
