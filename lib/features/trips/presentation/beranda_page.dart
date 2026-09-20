import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../recording/application/recording_controller.dart';
import '../data/trip_models.dart';

class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final trips = ref.watch(tripListProvider);
    final nama = ref.watch(savedNameProvider).value;
    final rekaman = ref.watch(recordingControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: NapakColors.deepAccent,
          onRefresh: () async => ref.invalidate(tripListProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_salam(), style: text.bodyMedium?.copyWith(
                              color: NapakColors.textSecondary,
                            )),
                            const SizedBox(height: 2),
                            Text(nama ?? 'Penjejak', style: text.headlineSmall),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _gabungBareng(context, ref),
                        icon: const Icon(Icons.group_add_outlined),
                        color: NapakColors.deepAccent,
                        tooltip: 'Gabung Trip Bareng',
                      ),
                      IconButton(
                        onPressed: () => context.push('/recap'),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        color: NapakColors.deepAccent,
                        tooltip: 'Napak Tilas tahunan',
                      ),
                      IconButton(
                        onPressed: () => context.push('/pengaturan'),
                        icon: const Icon(Icons.settings_outlined),
                        color: NapakColors.deepAccent,
                        tooltip: 'Pengaturan',
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: _AntreanJejak()),
              if (rekaman.isRecording)
                const SliverToBoxAdapter(child: _SedangMerekam()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text('Jejakmu', style: text.titleLarge),
                ),
              ),
              trips.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: _PesanKosong(
                    ikon: Icons.cloud_off_rounded,
                    judul: 'Belum tersambung',
                    keterangan: error.toString(),
                    aksi: FilledButton(
                      onPressed: () => ref.invalidate(tripListProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ),
                ),
                data: (daftar) {
                  if (daftar.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _PesanKosong(
                        ikon: Icons.route_outlined,
                        judul: 'Belum ada jejak di sini',
                        keterangan:
                            'Mulai perjalanan pertamamu. Napak akan merekam '
                            'diam-diam sementara kamu menikmati jalannya.',
                      ),
                    );
                  }
                  return SliverList.separated(
                    itemCount: daftar.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            0,
                            24,
                            index == daftar.length - 1 ? 120 : 0,
                          ),
                          child: _KartuTrip(trip: daftar[index]),
                        ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: rekaman.isRecording
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _tanyaJudul(context, ref),
              backgroundColor: NapakColors.deepAccent,
              foregroundColor: NapakColors.textOnDeep,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mulai merekam'),
            ),
    );
  }

  /// Gabung ke perjalanan orang lain lewat kode undangan.
  Future<void> _gabungBareng(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final gabung = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NapakColors.base,
        title: const Text('Gabung Trip Bareng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan kode undangan dari pemimpin perjalanan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Kode undangan'),
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
            child: const Text('Gabung'),
          ),
        ],
      ),
    );

    if (gabung != true || controller.text.trim().isEmpty) return;

    try {
      final anggota = await ref
          .read(tripRepositoryProvider)
          .joinBySlug(controller.text.trim());
      ref.invalidate(tripListProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kamu bergabung sebagai ${anggota.name}. Selamat jalan bareng.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  static String _salam() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi,';
    if (jam < 15) return 'Selamat siang,';
    if (jam < 19) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  Future<void> _tanyaJudul(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var mode = TripMode.solo;

    final mulai = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mau ke mana hari ini?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Mudik ke Solo',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TripMode>(
                segments: const [
                  ButtonSegment(
                    value: TripMode.solo,
                    label: Text('Sendiri'),
                    icon: Icon(Icons.person_outline_rounded),
                  ),
                  ButtonSegment(
                    value: TripMode.group,
                    label: Text('Bareng'),
                    icon: Icon(Icons.group_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (pilihan) =>
                    setSheetState(() => mode = pilihan.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: NapakColors.softSky,
                  selectedBackgroundColor: NapakColors.primary,
                  selectedForegroundColor: NapakColors.textPrimary,
                  foregroundColor: NapakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Mulai'),
              ),
            ],
          ),
        ),
      ),
    );

    if (mulai != true) return;
    final judul = controller.text.trim().isEmpty
        ? 'Perjalanan ${DateFormat('d MMMM', 'id_ID').format(DateTime.now())}'
        : controller.text.trim();

    await ref
        .read(recordingControllerProvider.notifier)
        .start(title: judul, mode: mode);

    final state = ref.read(recordingControllerProvider);
    if (state.message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message!)));
    }
    ref.invalidate(tripListProvider);
  }
}

/// Pemberitahuan tenang saat ada jejak yang belum sempat terkirim.
class _AntreanJejak extends ConsumerWidget {
  const _AntreanJejak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlah = ref.watch(pendingPointCountProvider).value ?? 0;
    if (jumlah == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NapakColors.warmNeutral,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_sync_outlined,
              size: 18,
              color: NapakColors.deepAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$jumlah jejak menunggu sinyal. Sudah aman tersimpan di HP-mu.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NapakColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SedangMerekam extends ConsumerWidget {
  const _SedangMerekam();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NapakColors.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _TitikBerdenyut(),
                const SizedBox(width: 10),
                Text('Sedang merekam', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(state.title ?? 'Perjalanan', style: text.bodyLarge),
            const SizedBox(height: 4),
            Text('${state.recordedCount} jejak terekam', style: text.bodySmall),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tambahCatatan(context, ref),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Catatan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(recordingControllerProvider.notifier).stop(),
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tambahCatatan(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final simpan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NapakColors.base,
        title: const Text('Ada apa di sini?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Berhenti makan soto di pinggir jalan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (simpan == true) {
      await ref
          .read(recordingControllerProvider.notifier)
          .addNote(controller.text);
    }
  }
}

class _TitikBerdenyut extends StatefulWidget {
  const _TitikBerdenyut();

  @override
  State<_TitikBerdenyut> createState() => _TitikBerdenyutState();
}

class _TitikBerdenyutState extends State<_TitikBerdenyut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.35, end: 1)),
      child: Container(
        height: 10,
        width: 10,
        decoration: const BoxDecoration(
          color: NapakColors.deepAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _KartuTrip extends StatelessWidget {
  const _KartuTrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.push('/trip/${trip.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NapakColors.softSky,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(trip.title, style: text.titleMedium)),
                if (trip.isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: NapakColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Berjalan',
                      style: text.labelMedium?.copyWith(
                        color: NapakColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Keping(
                  ikon: Icons.straighten_rounded,
                  teks: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 16),
                _Keping(
                  ikon: trip.mode == TripMode.group
                      ? Icons.group_outlined
                      : Icons.person_outline_rounded,
                  teks: trip.mode.label,
                ),
                const SizedBox(width: 16),
                _Keping(
                  ikon: switch (trip.visibility) {
                    TripVisibility.private => Icons.lock_outline_rounded,
                    TripVisibility.link => Icons.link_rounded,
                    TripVisibility.public => Icons.public_rounded,
                  },
                  teks: trip.visibility.label,
                ),
              ],
            ),
            if (trip.startedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                DateFormat("d MMMM yyyy", 'id_ID').format(trip.startedAt!),
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Keping extends StatelessWidget {
  const _Keping({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 15, color: NapakColors.deepAccent),
        const SizedBox(width: 5),
        Text(teks, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PesanKosong extends StatelessWidget {
  const _PesanKosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
      child: Column(
        children: [
          Icon(ikon, size: 44, color: NapakColors.primary),
          const SizedBox(height: 20),
          Text(judul, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(keterangan, style: text.bodySmall, textAlign: TextAlign.center),
          if (aksi != null) ...[const SizedBox(height: 24), aksi!],
        ],
      ),
    );
  }
}
