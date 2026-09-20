import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';

/// Layar kode OTP.
///
/// Nama hanya ditanyakan kalau ini perjalanan pertamamu bersama Napak — dan
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode baru sudah dikirim.')),
      );
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

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cek SMS-mu', style: text.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Kode enam angka sudah meluncur ke ${widget.phoneNumber}.',
                style: text.bodyLarge?.copyWith(
                  color: NapakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _kodeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: text.headlineMedium?.copyWith(letterSpacing: 14),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '······',
                  hintStyle: text.headlineMedium?.copyWith(
                    letterSpacing: 14,
                    color: NapakColors.divider,
                  ),
                  errorText: _kesalahan,
                ),
                onChanged: (value) {
                  if (value.length == 6) _periksa();
                },
              ),
              const SizedBox(height: 20),
              Text('Namamu', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Dipakai kalau ini pertama kalinya kamu di Napak. '
                'Bisa diganti kapan saja.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _namaController,
                textCapitalization: TextCapitalization.words,
                style: text.bodyLarge,
                decoration: const InputDecoration(hintText: 'Nama panggilan'),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _memeriksa ? null : _periksa,
                child: _memeriksa
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NapakColors.textOnDeep,
                        ),
                      )
                    : const Text('Masuk'),
              ),
              const SizedBox(height: 16),
              Center(
                child: _detikTersisa > 0
                    ? Text('Bisa minta kode baru dalam $_waktu', style: text.bodySmall)
                    : TextButton(
                        onPressed: _kirimUlang,
                        child: const Text('Kirim ulang kode'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
