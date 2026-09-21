import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../data/sosial_repository.dart';
import 'komponen_sosial.dart';

/// Lembar untuk mengirim satu singgahan berfoto sebagai kartu pos.
class KirimKartuPosSheet extends ConsumerStatefulWidget {
  const KirimKartuPosSheet({
    required this.titikId,
    required this.fotoUrl,
    super.key,
  });

  final String titikId;
  final String fotoUrl;

  static Future<void> tampilkan(
    BuildContext context, {
    required String titikId,
    required String fotoUrl,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NapakColors.base,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) =>
        KirimKartuPosSheet(titikId: titikId, fotoUrl: fotoUrl),
  );

  @override
  ConsumerState<KirimKartuPosSheet> createState() => _KirimKartuPosSheetState();
}

class _KirimKartuPosSheetState extends ConsumerState<KirimKartuPosSheet> {
  final _pesan = TextEditingController();
  String? _penerima;
  bool _mengirim = false;
  bool _terkirim = false;

  @override
  void dispose() {
    _pesan.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final penerima = _penerima;
    if (penerima == null) return;
    setState(() => _mengirim = true);

    try {
      await ref
          .read(sosialRepositoryProvider)
          .kirimKartuPos(
            titikId: widget.titikId,
            penerimaId: penerima,
            pesan: _pesan.text,
          );
      HapticFeedback.heavyImpact();
      ref.invalidate(kartuPosTerkirimProvider);
      setState(() => _terkirim = true);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) Navigator.of(context).pop();
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedSwitcher(
        duration: NapakMotion.sedang,
        child: _terkirim
            ? _Terkirim(fotoUrl: widget.fotoUrl)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: Column(
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
                    const SizedBox(height: 18),
                    Text('Kirim sebagai kartu pos', style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Fotonya disalin untuk temanmu. Jejak perjalananmu '
                      'sendiri tetap tertutup.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Image.network(widget.fotoUrl, fit: BoxFit.cover),
                      ),
                    ).animate().fadeIn().scaleXY(begin: 0.95),
                    const SizedBox(height: 18),
                    Text('Untuk', style: text.labelLarge),
                    const SizedBox(height: 8),
                    teman.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(e.toString()),
                      data: (daftar) => daftar.isEmpty
                          ? TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.push('/teman');
                              },
                              icon: const Icon(Icons.group_add_outlined),
                              label: const Text(
                                'Tambahkan teman dulu lewat kode Napak',
                              ),
                            )
                          : SizedBox(
                              height: 86,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: daftar.length,
                                separatorBuilder: (context, i) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (context, i) {
                                  final t = daftar[i];
                                  final dipilih = _penerima == t.id;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _penerima = t.id);
                                    },
                                    child: AnimatedScale(
                                      duration: NapakMotion.cepat,
                                      curve: NapakMotion.memantul,
                                      scale: dipilih ? 1.08 : 1,
                                      child: SizedBox(
                                        width: 64,
                                        child: Column(
                                          children: [
                                            LingkaranNama(
                                              nama: t.nama,
                                              ukuran: 52,
                                              cincin: dipilih,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              t.nama.split(' ').first,
                                              style: text.labelSmall?.copyWith(
                                                color: dipilih
                                                    ? NapakColors.deepAccent
                                                    : NapakColors.textSecondary,
                                                fontWeight: dipilih
                                                    ? FontWeight.w700
                                                    : null,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pesan,
                      maxLength: 280,
                      minLines: 2,
                      maxLines: 4,
                      style: GoogleFonts.caveat(fontSize: 22),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Tulis sesuatu di baliknya…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _penerima == null || _mengirim
                            ? null
                            : _kirim,
                        icon: _mengirim
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NapakColors.textOnDeep,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: const Text('Kirim kartu pos'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Kartunya terbang pergi ke kotak pos.
class _Terkirim extends StatelessWidget {
  const _Terkirim({required this.fotoUrl});

  final String fotoUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                    Icons.local_post_office_rounded,
                    size: 64,
                    color: NapakColors.deepAccent,
                  )
                  .animate()
                  .scaleXY(
                    begin: 0.4,
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  )
                  .then(delay: 500.ms)
                  .shake(hz: 4, rotation: 0.05, duration: 400.ms),
              const SizedBox(height: 16),
              Text(
                'Terkirim',
                style: Theme.of(context).textTheme.titleLarge,
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
          // Foto kecil yang melesat masuk ke kotak pos.
          ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 120,
                  height: 80,
                  child: Image.network(fotoUrl, fit: BoxFit.cover),
                ),
              )
              .animate()
              .moveY(
                begin: -120,
                end: -30,
                duration: 450.ms,
                curve: Curves.easeIn,
              )
              .scaleXY(end: 0.1, delay: 250.ms, duration: 300.ms)
              .fadeOut(delay: 450.ms, duration: 150.ms),
        ],
      ),
    );
  }
}
