import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../data/sosial_repository.dart';
import 'komponen_sosial.dart';

/// Mengundang teman ke sebuah Trip Bareng, tanpa mengeja kode.
class UndangTemanSheet extends ConsumerStatefulWidget {
  const UndangTemanSheet({required this.tripId, super.key});

  final String tripId;

  static Future<void> tampilkan(BuildContext context, String tripId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: TourvellaColors.base,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => UndangTemanSheet(tripId: tripId),
      );

  @override
  ConsumerState<UndangTemanSheet> createState() => _UndangTemanSheetState();
}

class _UndangTemanSheetState extends ConsumerState<UndangTemanSheet> {
  final _dipilih = <String>{};
  bool _mengirim = false;

  Future<void> _undang() async {
    setState(() => _mengirim = true);
    try {
      final pesan = await ref
          .read(sosialRepositoryProvider)
          .undang(widget.tripId, _dipilih.toList());
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesan)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _mengirim = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final teman = ref.watch(daftarTemanProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TourvellaColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Ajak teman berangkat', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Undangannya masuk ke kabar mereka. Posisi langsung tetap mati '
              'sampai tiap orang menyalakannya sendiri.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: teman.when(
                loading: () => const KerangkaDaftarOrang(jumlah: 3),
                error: (e, _) => Text(e.toString()),
                data: (daftar) => daftar.isEmpty
                    ? const KosongHangat(
                        ikon: Icons.group_add_outlined,
                        judul: 'Belum ada teman',
                        isi: 'Tambahkan teman lewat kode Tourvella dulu.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: daftar.length,
                        itemBuilder: (context, i) {
                          final t = daftar[i];
                          final pilih = _dipilih.contains(t.id);
                          return CheckboxListTile(
                                value: pilih,
                                onChanged: (v) {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => v == true
                                        ? _dipilih.add(t.id)
                                        : _dipilih.remove(t.id),
                                  );
                                },
                                contentPadding: EdgeInsets.zero,
                                secondary: LingkaranNama(
                                  nama: t.nama,
                                  cincin: pilih,
                                ),
                                title: Text(t.nama),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              )
                              .animate(delay: (45 * i).ms)
                              .fadeIn(duration: TourvellaMotion.cepat)
                              .slideX(begin: 0.06);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _dipilih.isEmpty || _mengirim ? null : _undang,
                child: AnimatedSwitcher(
                  duration: TourvellaMotion.cepat,
                  child: Text(
                    _dipilih.isEmpty
                        ? 'Pilih teman'
                        : 'Undang ${_dipilih.length} orang',
                    key: ValueKey(_dipilih.length),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
