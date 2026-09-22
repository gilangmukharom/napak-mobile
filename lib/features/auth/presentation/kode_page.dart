import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/theme/tourvella_theme.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';

/// Layar kode OTP.
///
/// Nama hanya ditanyakan kalau ini perjalanan pertamamu bersama Tourvella — dan
/// itu baru ketahuan setelah kodenya benar, karena backend sengaja tidak
/// membocorkan nomor mana yang sudah terdaftar.
class KodePage extends ConsumerStatefulWidget {
  const KodePage({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  ConsumerState<KodePage> createState() => _KodePageState();
}

class _KodePageState extends ConsumerState<KodePage> {
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  Timer? _hitungMundur;
  int _detikTersisa = 300;
  bool _memeriksa = false;
  String? _kesalahan;

  @override
  void initState() {
    super.initState();
    _mulaiHitungMundur();
  }

  @override
  void dispose() {
    _hitungMundur?.cancel();
    _kodeController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  void _mulaiHitungMundur() {
    _hitungMundur?.cancel();
    setState(() => _detikTersisa = 300);
    _hitungMundur = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_detikTersisa <= 1) {
        timer.cancel();
        setState(() => _detikTersisa = 0);
      } else {
        setState(() => _detikTersisa--);
      }
    });
  }

  Future<void> _kirimUlang() async {
    try {
      await ref.read(authRepositoryProvider).requestCode(widget.phoneNumber);
      _mulaiHitungMundur();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kode baru sudah dikirim.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _kesalahan = error.toString());
    }
  }

  Future<void> _periksa() async {
    if (_kodeController.text.length != 6) {
      setState(() => _kesalahan = 'Kodenya terdiri dari 6 angka.');
      return;
    }

    setState(() {
      _memeriksa = true;
      _kesalahan = null;
    });

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyCode(
            phoneNumber: widget.phoneNumber,
            code: _kodeController.text,
            name: _namaController.text,
          );

      ref.invalidate(sessionProvider);
      ref.invalidate(savedNameProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(session.message)));
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _kesalahan = error.toString());
    } finally {
      if (mounted) setState(() => _memeriksa = false);
    }
  }

  String get _waktu {
    final menit = (_detikTersisa ~/ 60).toString();
    final detik = (_detikTersisa % 60).toString().padLeft(2, '0');
    return '$menit:$detik';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    const bingkai = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: TourvellaColors.kontur),
    );

    return Theme(
      data: TourvellaTheme.gelap(),
      child: Scaffold(
        backgroundColor: TourvellaColors.malam,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: TourvellaColors.base,
          leading: const BackButton(),
        ),
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
                heightFactor: 0.34,
                child: SiluetGunung(
                  warna: [TourvellaColors.malamNaik, TourvellaColors.malam],
                ),
              ),
            ),
            const ButiranKertas(opasitas: 0.045),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelKapital(
                      'Satu langkah lagi',
                      warna: TourvellaColors.ember,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cek SMS-mu',
                      style: text.headlineMedium?.copyWith(
                        color: TourvellaColors.base,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kode enam angka sudah meluncur ke '
                      '${widget.phoneNumber}.',
                      style: text.bodyLarge?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _kodeController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: text.headlineMedium?.copyWith(
                        letterSpacing: 14,
                        color: TourvellaColors.ember,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: TourvellaColors.malamNaik.withValues(
                          alpha: 0.8,
                        ),
                        hintText: '······',
                        hintStyle: text.headlineMedium?.copyWith(
                          letterSpacing: 14,
                          color: TourvellaColors.kontur,
                        ),
                        errorText: _kesalahan,
                        enabledBorder: bingkai,
                        focusedBorder: bingkai.copyWith(
                          borderSide: const BorderSide(
                            color: TourvellaColors.ember,
                            width: 1.6,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.length == 6) _periksa();
                      },
                    ),
                    const SizedBox(height: 22),
                    const LabelKapital('Namamu'),
                    const SizedBox(height: 6),
                    Text(
                      'Dipakai kalau ini pertama kalinya kamu di Tourvella. '
                      'Bisa diganti kapan saja.',
                      style: text.bodySmall?.copyWith(
                        color: TourvellaColors.base.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _namaController,
                      textCapitalization: TextCapitalization.words,
                      style: text.bodyLarge?.copyWith(
                        color: TourvellaColors.base,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: TourvellaColors.malamNaik.withValues(
                          alpha: 0.8,
                        ),
                        hintText: 'Nama panggilan',
                        enabledBorder: bingkai,
                        focusedBorder: bingkai.copyWith(
                          borderSide: const BorderSide(
                            color: TourvellaColors.ember,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _memeriksa ? null : _periksa,
                        child: _memeriksa
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TourvellaColors.malam,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _detikTersisa > 0
                          ? LabelKapital(
                              'Kode baru dalam $_waktu',
                              warna: TourvellaColors.base.withValues(
                                alpha: 0.45,
                              ),
                            )
                          : TextButton(
                              onPressed: _kirimUlang,
                              child: const Text('Kirim ulang kode'),
                            ),
                    ),
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
