import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';

/// Pintu masuk Napak.
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _JejakOrnamen(),
              const SizedBox(height: 40),
              Text('Napak', style: text.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Setiap perjalanan meninggalkan jejak.\n'
                'Napak menyimpannya untukmu.',
                style: text.bodyLarge?.copyWith(
                  color: NapakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 44),
              Text('Nomor HP', style: text.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: text.bodyLarge,
                decoration: InputDecoration(
                  hintText: '0812 3456 7890',
                  errorText: _kesalahan,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.phone_iphone_rounded,
                      color: NapakColors.deepAccent,
                      size: 20,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
                onSubmitted: (_) => _kirimKode(),
              ),
              const SizedBox(height: 10),
              Text(
                'Kami kirim kode enam angka lewat SMS.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _mengirim ? null : _kirimKode,
                child: _mengirim
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NapakColors.textOnDeep,
                        ),
                      )
                    : const Text('Kirim kode'),
              ),
              const SizedBox(height: 32),
              const _JanjiPrivasi(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Garis jejak yang melengkung — sepotong rute, bukan sekadar hiasan.
class _JejakOrnamen extends StatelessWidget {
  const _JejakOrnamen();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(painter: _JejakPainter()),
    );
  }
}

class _JejakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.1,
        size.width * 0.42,
        size.height * 1.0,
        size.width * 0.66,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.1,
        size.width * 0.88,
        size.height * 0.2,
        size.width,
        size.height * 0.28,
      );

    // Gradasi deepAccent -> primary: jejak yang mengalir dan menipis.
    final paint = Paint()
      ..shader = const LinearGradient(colors: NapakColors.routeGradient)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width, size.height * 0.28),
      5,
      Paint()..color = NapakColors.deepAccent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JanjiPrivasi extends StatelessWidget {
  const _JanjiPrivasi();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Aksen hangat, penyeimbang dominasi biru.
        color: NapakColors.warmNeutral,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: NapakColors.deepAccent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Semua perjalananmu tersimpan tertutup. '
              'Kamu sendiri yang memutuskan kapan sebuah jejak dibagikan.',
              style: text.bodySmall?.copyWith(color: NapakColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
