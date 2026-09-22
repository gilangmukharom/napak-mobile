import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/theme/tourvella_theme.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_logo.dart';

/// Pintu masuk Tourvella.
///
/// Hanya meminta nomor HP. Tidak ada kata sandi untuk dilupakan, tidak ada
/// email untuk diverifikasi, tidak ada tombol "masuk dengan" milik perusahaan
/// lain yang ikut tahu kamu memakai aplikasi ini.
class MasukPage extends ConsumerStatefulWidget {
  const MasukPage({super.key});

  @override
  ConsumerState<MasukPage> createState() => _MasukPageState();
}

class _MasukPageState extends ConsumerState<MasukPage> {
  final _controller = TextEditingController();
  bool _mengirim = false;
  String? _kesalahan;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _kirimKode() async {
    final nomor = _controller.text.trim();
    if (nomor.length < 8) {
      setState(() => _kesalahan = 'Nomornya sepertinya belum lengkap.');
      return;
    }

    setState(() {
      _mengirim = true;
      _kesalahan = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestCode(nomor);
      if (!mounted) return;
      context.push('/masuk/kode', extra: nomor);
    } catch (error) {
      if (!mounted) return;
      setState(() => _kesalahan = error.toString());
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Pintu masuk dibuat segelap layar pembukanya: orang yang baru menutup
    // splash tidak seharusnya disambut kilatan putih.
    return Theme(
      data: TourvellaTheme.gelap(),
      child: Scaffold(
        backgroundColor: TourvellaColors.malam,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: TourvellaColors.langitSubuh,
                  stops: [0, 0.5, 1.4],
                ),
              ),
            ),
            const IgnorePointer(child: KonturTopografi(opasitas: 0.14)),
            const Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.42,
                child: SiluetGunung(
                  warna: [
                    Color(0xFF2E3B4E),
                    TourvellaColors.malamNaik,
                    TourvellaColors.malam,
                  ],
                ),
              ),
            ),
            const ButiranKertas(opasitas: 0.045),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _JejakOrnamen(),
                    const SizedBox(height: 32),
                    LabelKapital(
                      'Buka perjalanan',
                      warna: TourvellaColors.ember,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tourvella',
                      style: text.displaySmall?.copyWith(
                        color: TourvellaColors.base,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Setiap perjalanan punya cerita.\n'
                      'Rekam jalanmu, bagikan ceritamu.',
                      style: text.bodyLarge?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const LabelKapital('Nomor HP'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      style: text.bodyLarge?.copyWith(
                        color: TourvellaColors.base,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 1.1,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: TourvellaColors.malamNaik.withValues(
                          alpha: 0.8,
                        ),
                        hintText: '0812 3456 7890',
                        errorText: _kesalahan,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: TourvellaColors.kontur,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: TourvellaColors.ember,
                            width: 1.6,
                          ),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 16, right: 8),
                          child: Icon(
                            Icons.phone_iphone_rounded,
                            color: TourvellaColors.ember,
                            size: 20,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                        ),
                      ),
                      onSubmitted: (_) => _kirimKode(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kami kirim kode enam angka lewat SMS.',
                      style: text.bodySmall?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _mengirim ? null : _kirimKode,
                        child: _mengirim
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TourvellaColors.malam,
                                ),
                              )
                            : const Text('Kirim kode'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _JanjiPrivasi(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Garis jejak yang melengkung — sepotong rute, bukan sekadar hiasan.
/// Tanda Tourvella yang menyusun dirinya sekali saat layar dibuka —
/// kelanjutan dari layar pembuka, bukan hiasan baru.
class _JejakOrnamen extends StatefulWidget {
  const _JejakOrnamen();

  @override
  State<_JejakOrnamen> createState() => _JejakOrnamenState();
}

class _JejakOrnamenState extends State<_JejakOrnamen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: TourvellaMotion.pembuka,
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
      builder: (context, _) =>
          LogoTourvella(ukuran: 76, progres: _kendali.value),
    );
  }
}

class _JanjiPrivasi extends StatelessWidget {
  const _JanjiPrivasi();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TourvellaColors.malamNaik.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TourvellaColors.kontur),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: TourvellaColors.emberRedup,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Semua perjalananmu tersimpan tertutup. '
              'Kamu sendiri yang memutuskan kapan sebuah jejak dibagikan.',
              style: text.bodySmall?.copyWith(
                color: TourvellaColors.base.withValues(alpha: 0.72),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
