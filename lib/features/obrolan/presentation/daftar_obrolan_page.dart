import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../data/obrolan_data.dart';

class DaftarObrolanPage extends ConsumerWidget {
  const DaftarObrolanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(daftarObrolanProvider);

    return Scaffold(
      backgroundColor: NapakColors.base,
      appBar: AppBar(
        title: const Text('Obrolan'),
        actions: [
          IconButton(
            tooltip: 'Mulai obrolan dengan teman',
            onPressed: () => context.push('/teman'),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(daftarObrolanProvider.future),
        child: daftar.when(
          loading: () => const KerangkaDaftarOrang(),
          error: (galat, _) => ListView(
            children: [
              KosongHangat(
                ikon: Icons.cloud_off_rounded,
                judul: 'Obrolan belum bisa dimuat',
                isi: galat.toString(),
              ),
            ],
          ),
          data: (percakapan) {
            if (percakapan.isEmpty) {
              return ListView(
                children: [
                  KosongHangat(
                    ikon: Icons.forum_outlined,
                    judul: 'Belum ada obrolan',
                    isi:
                        'Obrolan cuma bisa dengan teman. Tambahkan teman lewat '
                        'kode Napak, lalu sapa mereka dari sana.',
                    aksi: FilledButton.icon(
                      onPressed: () => context.push('/teman'),
                      icon: const Icon(Icons.group_add_outlined, size: 20),
                      label: const Text('Ke daftar teman'),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: percakapan.length + 1,
              itemBuilder: (context, i) {
                if (i == percakapan.length) return const _CatatanSimpan();
                return MunculBertahap(
                  indeks: i,
                  child: _BarisPercakapan(p: percakapan[i]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BarisPercakapan extends ConsumerWidget {
  const _BarisPercakapan({required this.p});

  final Percakapan p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final belum = p.belumDibaca > 0;

    return NapakPressable(
      onTap: () async {
        await context.push(
          '/obrolan/${p.id}',
          extra: (judul: p.judul, rombongan: p.rombongan),
        );
        // Angka belum-dibacanya ikut turun setelah kembali.
        ref.invalidate(daftarObrolanProvider);
      },
      skala: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Hero(
              tag: 'obrolan-${p.id}',
              child: p.rombongan
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: NapakColors.routeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: NapakColors.textOnDeep,
                      ),
                    )
                  : LingkaranNama(nama: p.judul, ukuran: 52),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.judul,
                          style: text.titleSmall?.copyWith(
                            fontWeight: belum ? FontWeight.w700 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.waktuTerakhir != null)
                        Text(
                          waktuSantai(p.waktuTerakhir!),
                          style: text.bodySmall?.copyWith(
                            color: belum
                                ? NapakColors.deepAccent
                                : NapakColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.pesanTerakhir == null
                              ? 'Belum ada pesan'
                              : '${p.terakhirOlehSaya ? 'Kamu: ' : ''}${p.pesanTerakhir}',
                          style: text.bodyMedium?.copyWith(
                            color: belum
                                ? NapakColors.textPrimary
                                : NapakColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      LencanaAngka(angka: p.belumDibaca),
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

/// Keterangan masa simpan, supaya tidak ada yang kaget pesannya hilang.
class _CatatanSimpan extends StatelessWidget {
  const _CatatanSimpan();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: NapakColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pesan disimpan terenkripsi dan dibuang sendiri setelah enam '
              'bulan. Obrolan rombongan ikut hilang saat perjalanannya dihapus.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
