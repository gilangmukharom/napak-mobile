import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../data/simulasi_data.dart';

/// Saklar rombongan simulasi.
///
/// **Alat pengembangan, dan ditulis begitu di layarnya** — bukan fitur yang
/// disamarkan jadi fitur. Muncul hanya kalau server mengizinkan; di produksi
/// kartunya tidak pernah ada.
class KartuSimulasiRombongan extends ConsumerStatefulWidget {
  const KartuSimulasiRombongan({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<KartuSimulasiRombongan> createState() =>
      _KartuSimulasiRombonganState();
}

class _KartuSimulasiRombonganState
    extends ConsumerState<KartuSimulasiRombongan> {
  bool _menunggu = false;

  Future<void> _atur(bool nyala) async {
    setState(() => _menunggu = true);
    final repo = ref.read(simulasiRepositoryProvider);
    try {
      if (nyala) {
        await repo.mulai(widget.tripId);
      } else {
        await repo.berhenti(widget.tripId);
      }
      ref.invalidate(simulasiBerjalanProvider(widget.tripId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _menunggu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tersedia = ref.watch(simulasiTersediaProvider).value ?? false;
    if (!tersedia) return const SizedBox.shrink();

    final berjalan = ref.watch(simulasiBerjalanProvider(widget.tripId));
    final nyala = berjalan.value ?? false;
    final text = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: TourvellaMotion.sedang,
      curve: TourvellaMotion.mengalir,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: nyala
            ? TourvellaColors.warmNeutral
            : TourvellaColors.softSky.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: nyala ? TourvellaColors.ember : TourvellaColors.divider,
          width: nyala ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            color: nyala
                ? TourvellaColors.ember
                : TourvellaColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rombongan simulasi', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  nyala
                      ? 'Lima rekan palsu berbaris 50 m di belakangmu. Namanya '
                            'berakhiran "(simulasi)".'
                      : 'Untuk mencoba konvoi dan telepon rombongan tanpa lima '
                            'HP. Alat pengembangan, bukan teman sungguhan.',
                  style: text.bodySmall?.copyWith(
                    color: TourvellaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_menunggu || berjalan.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(value: nyala, onChanged: _atur),
        ],
      ),
    );
  }
}
