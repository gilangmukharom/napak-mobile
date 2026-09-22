import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../application/navigasi_controller.dart';
import '../application/ucapan_navigasi.dart';

/// Petunjuk arah di layar rekam.
///
/// Dibaca sambil jalan, jadi susunannya: panah besar, jarak besar, nama
/// jalan kecil. Yang tidak ada di sini juga disengaja — tidak ada daftar
/// langkah, tidak ada perkiraan tiba yang berubah tiap detik. Di atas motor,
/// yang dibutuhkan cuma "belok ke mana, berapa lama lagi".
class PanelNavigasi extends ConsumerWidget {
  const PanelNavigasi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigasiControllerProvider);
    final aksi = ref.read(navigasiControllerProvider.notifier);
    final langkah = nav.langkah;
    final keadaan = nav.keadaan;
    final text = Theme.of(context).textTheme;

    if (!nav.aktif || langkah == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: TourvellaColors.malam.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: TourvellaColors.textPrimary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: TourvellaMotion.cepat,
              child: Icon(
                ikonManuver(langkah),
                key: ValueKey('${langkah.jenis}-${langkah.arah}'),
                color: TourvellaColors.ember,
                size: 40,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nav.menghitungUlang
                        ? 'Menghitung ulang…'
                        : keadaan == null
                        ? 'Mencari posisimu…'
                        : jarakSingkat(keadaan.jarakKeManuverM),
                    style: text.headlineSmall?.copyWith(
                      color: TourvellaColors.base,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    kalimatManuver(langkah),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: TourvellaColors.base.withValues(alpha: 0.75),
                    ),
                  ),
                  if (keadaan != null)
                    Text(
                      '${jarakSingkat(keadaan.sisaJarakM)} lagi ke ${nav.rute!.tujuan.nama}',
                      style: text.bodySmall?.copyWith(
                        color: TourvellaColors.emberRedup,
                      ),
                    ),
                ],
              ),
            ),
            _TombolKecil(
              ikon: nav.bisu
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              label: nav.bisu ? 'Nyalakan suara' : 'Bisukan suara navigasi',
              onTap: () => aksi.aturBisu(!nav.bisu),
            ),
            _TombolKecil(
              ikon: Icons.replay_rounded,
              label: 'Ulangi petunjuk',
              onTap: aksi.ulangi,
            ),
            _TombolKecil(
              ikon: Icons.close_rounded,
              label: 'Hentikan navigasi',
              onTap: aksi.berhenti,
            ),
          ],
        ),
      ),
    );
  }
}

class _TombolKecil extends StatelessWidget {
  const _TombolKecil({
    required this.ikon,
    required this.label,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: TourvellaPressable(
          skala: 0.9,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              ikon,
              color: TourvellaColors.base.withValues(alpha: 0.8),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
