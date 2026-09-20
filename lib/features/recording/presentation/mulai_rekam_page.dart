import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../trips/data/trip_models.dart';
import '../application/recording_controller.dart';

/// Layar memulai perjalanan.
///
/// Dulu ini lembar kecil yang muncul dari bawah. Dijadikan satu layar penuh
/// karena momennya memang bukan momen kecil: setelah tombol ini ditekan,
/// aplikasi akan mengikuti orangnya selama berjam-jam. Layar penuh memberi
/// ruang untuk mengatakan apa yang akan terjadi, bukan cuma meminta judul.
class MulaiRekamPage extends ConsumerStatefulWidget {
  const MulaiRekamPage({super.key});

  @override
  ConsumerState<MulaiRekamPage> createState() => _MulaiRekamPageState();
}

class _MulaiRekamPageState extends ConsumerState<MulaiRekamPage> {
  final _judul = TextEditingController();
  TripMode _mode = TripMode.solo;
  bool _memulai = false;

  @override
  void dispose() {
    _judul.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    setState(() => _memulai = true);

    final judul = _judul.text.trim().isEmpty
        ? 'Perjalanan ${DateFormat('d MMMM', 'id_ID').format(DateTime.now())}'
        : _judul.text.trim();

    await ref
        .read(recordingControllerProvider.notifier)
        .start(title: judul, mode: _mode);

    if (!mounted) return;
    final state = ref.read(recordingControllerProvider);
    setState(() => _memulai = false);

    if (state.isRecording) {
      // Menggantikan layar ini, bukan menumpuk — menekan kembali dari layar
      // perekaman semestinya pulang ke beranda, bukan kembali ke sini.
      context.pushReplacement('/rekam');
    } else if (state.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: NapakColors.textSecondary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                children: [
                  const MunculBertahap(
                    indeks: 0,
                    child: SizedBox(
                      height: 64,
                      child: _GarisPembuka(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  MunculBertahap(
                    indeks: 1,
                    child: Text('Mau ke mana?', style: text.displaySmall),
                  ),
                  const SizedBox(height: 10),
                  MunculBertahap(
                    indeks: 2,
                    child: Text(
                      'Napak akan merekam diam-diam sampai kamu bilang selesai. '
                      'Layar boleh dimatikan.',
                      style: text.bodyLarge?.copyWith(
                        color: NapakColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  MunculBertahap(
                    indeks: 3,
                    child: TextField(
                      controller: _judul,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      style: text.titleLarge,
                      decoration: const InputDecoration(
                        hintText: 'Mudik ke Solo',
                      ),
                      onSubmitted: (_) => _mulai(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  MunculBertahap(
                    indeks: 4,
                    child: Text(
                      'Boleh dikosongkan — nanti dinamai dengan tanggal hari ini.',
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 32),
                  MunculBertahap(
                    indeks: 5,
                    child: Row(
                      children: [
                        Expanded(
                          child: _PilihanMode(
                            ikon: Icons.person_outline_rounded,
                            judul: 'Sendiri',
                            keterangan: 'Cuma jejakmu',
                            terpilih: _mode == TripMode.solo,
                            onTap: () => setState(() => _mode = TripMode.solo),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PilihanMode(
                            ikon: Icons.group_outlined,
                            judul: 'Bareng',
                            keterangan: 'Teman bisa gabung',
                            terpilih: _mode == TripMode.group,
                            onTap: () => setState(() => _mode = TripMode.group),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: MunculBertahap(
                indeks: 6,
                child: FilledButton.icon(
                  onPressed: _memulai ? null : _mulai,
                  icon: _memulai
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NapakColors.textOnDeep,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_memulai ? 'Menyiapkan...' : 'Mulai merekam'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarisPembuka extends StatefulWidget {
  const _GarisPembuka();

  @override
  State<_GarisPembuka> createState() => _GarisPembukaState();
}

class _GarisPembukaState extends State<_GarisPembuka>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kendali,
      builder: (context, _) => JejakMenggambar(
        progres: Curves.easeInOutCubic.transform(_kendali.value),
        gradasi: NapakColors.routeGradient,
        tebal: 3,
      ),
    );
  }
}

class _PilihanMode extends StatelessWidget {
  const _PilihanMode({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.terpilih,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return NapakPressable(
      onTap: onTap,
      skala: 0.96,
      child: AnimatedContainer(
        duration: NapakMotion.cepat,
        curve: NapakMotion.mengalir,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: terpilih ? NapakColors.softSky : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: terpilih ? NapakColors.deepAccent : NapakColors.divider,
            width: terpilih ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ikon,
              size: 22,
              color: terpilih
                  ? NapakColors.deepAccent
                  : NapakColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(judul, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(keterangan, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
