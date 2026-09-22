import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../data/sosial_models.dart';
import '../data/sosial_repository.dart';
import 'komponen_sosial.dart';

/// Satu kartu pos: foto di depan, tulisan di belakang. Ketuk untuk membalik.
class KartuPosPage extends ConsumerWidget {
  const KartuPosPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kartu = ref.watch(kartuPosProvider(id));

    return Scaffold(
      backgroundColor: TourvellaColors.warmNeutral,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (kartu.value != null)
            IconButton(
              tooltip: 'Buang',
              onPressed: () async {
                final yakin = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Buang kartu pos ini?'),
                    content: const Text(
                      'Fotonya ikut dihapus dari penyimpanan. Tidak bisa '
                      'dikembalikan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Buang'),
                      ),
                    ],
                  ),
                );
                if (yakin != true) return;
                await ref.read(sosialRepositoryProvider).buangKartuPos(id);
                ref
                  ..invalidate(kartuPosMasukProvider)
                  ..invalidate(kartuPosTerkirimProvider);
                if (context.mounted) context.pop();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: kartu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => KosongHangat(
          ikon: Icons.local_post_office_outlined,
          judul: 'Kartu pos ini tidak ada',
          isi: galat.toString(),
        ),
        data: (k) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
              children: [
                Text(
                  k.untukSaya ? 'Dari ${k.dari}' : 'Kamu mengirim ini',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 18),
                KartuPosBolakBalik(kartu: k)
                    // Kartunya jatuh dari atas lalu mendarat miring sedikit,
                    // seperti baru dikeluarkan dari kotak pos.
                    .animate()
                    .slideY(
                      begin: -1.2,
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    )
                    .rotate(
                      begin: -0.04,
                      end: -0.008,
                      duration: 900.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 250.ms),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: TourvellaColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ketuk kartunya untuk membalik',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ).animate().fadeIn(delay: 1100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu yang bisa dibalik.
///
/// Dua sisinya dirender sungguhan dan diputar dengan perspektif, bukan
/// sekadar berganti gambar — kartu pos yang dibalik memang begitulah rasanya.
class KartuPosBolakBalik extends StatefulWidget {
  const KartuPosBolakBalik({required this.kartu, super.key});

  final KartuPos kartu;

  @override
  State<KartuPosBolakBalik> createState() => _KartuPosBolakBalikState();
}

class _KartuPosBolakBalikState extends State<KartuPosBolakBalik>
    with SingleTickerProviderStateMixin {
  late final AnimationController _balik = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void initState() {
    super.initState();
    // Kalau ada tulisannya, dibalik sendiri sekali setelah mendarat —
    // supaya orang tahu kartunya punya sisi belakang.
    if (widget.kartu.pesan != null) {
      Future<void>.delayed(const Duration(milliseconds: 1700), () {
        if (mounted && _balik.value == 0) _balik.forward();
      });
    }
  }

  @override
  void dispose() {
    _balik.dispose();
    super.dispose();
  }

  void _ketuk() {
    HapticFeedback.selectionClick();
    _balik.isCompleted || _balik.velocity > 0
        ? _balik.reverse()
        : _balik.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _ketuk,
      child: AnimatedBuilder(
        animation: _balik,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_balik.value);
          final sudut = t * math.pi;
          final belakang = sudut > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(sudut)
              // Terangkat sedikit di tengah putaran, seperti dipegang tangan.
              ..scaleByDouble(
                1 + math.sin(t * math.pi) * 0.04,
                1 + math.sin(t * math.pi) * 0.04,
                1,
                1,
              ),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: belakang
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _SisiBelakang(kartu: widget.kartu),
                    )
                  : _SisiDepan(kartu: widget.kartu),
            ),
          );
        },
      ),
    );
  }
}

class _Bingkai extends StatelessWidget {
  const _Bingkai({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TourvellaColors.base,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: TourvellaColors.textPrimary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }
}

class _SisiDepan extends StatelessWidget {
  const _SisiDepan({required this.kartu});

  final KartuPos kartu;

  @override
  Widget build(BuildContext context) {
    return _Bingkai(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: TourvellaColors.softSky),
            Image.network(
              kartu.fotoUrl,
              fit: BoxFit.cover,
              frameBuilder: (context, anak, frame, sinkron) => sinkron
                  ? anak
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: TourvellaMotion.sedang,
                      child: anak,
                    ),
              errorBuilder: (context, e, s) => const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: TourvellaColors.primary,
                ),
              ),
            ),
            if (kartu.tempat != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x8C000000)],
                    ),
                  ),
                  child: Text(
                    'Salam dari ${kartu.tempat!.split(',').first}',
                    style: GoogleFonts.caveat(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: TourvellaColors.textOnDeep,
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

class _SisiBelakang extends StatelessWidget {
  const _SisiBelakang({required this.kartu});

  final KartuPos kartu;

  @override
  Widget build(BuildContext context) {
    final tulisanTangan = GoogleFonts.caveat(
      fontSize: 22,
      height: 1.25,
      color: TourvellaColors.textPrimary,
    );

    return _Bingkai(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kiri: tulisan.
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        kartu.pesan ?? 'Dari perjalananku, untukmu.',
                        style: tulisanTangan,
                      ),
                    ),
                  ),
                  Text('— ${kartu.dari}', style: tulisanTangan),
                ],
              ),
            ),
          ),
          // Garis tengah, seperti kartu pos sungguhan.
          Container(width: 1, color: TourvellaColors.divider),
          // Kanan: perangko, cap, dan alamat.
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 74,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Align(
                          alignment: Alignment.topRight,
                          child: _Perangko(),
                        ),
                        Positioned(
                          right: 26,
                          top: 20,
                          child: _CapPos(
                            tempat: kartu.tempat,
                            tanggal: kartu.dibuat,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  for (var i = 0; i < 3; i++)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(top: 18),
                      color: TourvellaColors.divider,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Perangko bergerigi, bergambar gunung — dilukis, bukan gambar tempelan.
class _Perangko extends StatelessWidget {
  const _Perangko();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.05,
      child: CustomPaint(size: const Size(50, 60), painter: _PelukisPerangko()),
    );
  }
}

class _PelukisPerangko extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Tepi bergerigi: persegi dikurangi deretan lingkaran kecil.
    final tepi = Path()..addRect(Offset.zero & size);
    const jari = 2.6;
    const jarak = 7.0;
    for (var x = jarak / 2; x < size.width; x += jarak) {
      tepi
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: jari))
        ..addOval(
          Rect.fromCircle(center: Offset(x, size.height), radius: jari),
        );
    }
    for (var y = jarak / 2; y < size.height; y += jarak) {
      tepi
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: jari))
        ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: jari));
    }
    tepi.fillType = PathFillType.evenOdd;
    canvas.drawPath(tepi, Paint()..color = TourvellaColors.warmNeutral);

    final dalam = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    canvas.drawRect(dalam, Paint()..color = TourvellaColors.softSky);

    // Gunung dan matahari.
    final gunung = Path()
      ..moveTo(dalam.left, dalam.bottom)
      ..lineTo(dalam.left + dalam.width * 0.35, dalam.top + dalam.height * 0.4)
      ..lineTo(dalam.left + dalam.width * 0.55, dalam.top + dalam.height * 0.62)
      ..lineTo(dalam.left + dalam.width * 0.75, dalam.top + dalam.height * 0.3)
      ..lineTo(dalam.right, dalam.bottom)
      ..close();
    canvas
      ..drawCircle(
        Offset(dalam.left + dalam.width * 0.7, dalam.top + dalam.height * 0.22),
        4,
        Paint()..color = TourvellaColors.base,
      )
      ..drawPath(gunung, Paint()..color = TourvellaColors.deepAccent);

    final tulisan = TextPainter(
      text: const TextSpan(
        text: 'TOURVELLA',
        style: TextStyle(
          fontSize: 5.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: TourvellaColors.textOnDeep,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Sembilan huruf di perangko selebar 38 px: kecilkan kalau fontnya
    // lebih lebar dari perkiraan, jangan biarkan meluber keluar gerigi.
    final muat = dalam.width - 4;
    final skala = tulisan.width > muat ? muat / tulisan.width : 1.0;
    canvas
      ..save()
      ..translate(dalam.center.dx, dalam.bottom - 9)
      ..scale(skala);
    tulisan.paint(canvas, Offset(-tulisan.width / 2, 0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cap pos bundar bertinta pudar, dengan nama tempat dan tanggal.
class _CapPos extends StatelessWidget {
  const _CapPos({required this.tempat, required this.tanggal});

  final String? tempat;
  final DateTime tanggal;

  @override
  Widget build(BuildContext context) {
    final warna = TourvellaColors.deepAccent.withValues(alpha: 0.55);
    final kota = (tempat ?? 'TOURVELLA').split(',').first.toUpperCase();

    return Transform.rotate(
      angle: -0.28,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: warna, width: 1.6),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kota.length > 10 ? kota.substring(0, 10) : kota,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w800,
                color: warna,
                letterSpacing: 0.6,
              ),
            ),
            Container(
              height: 1,
              width: 36,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: warna,
            ),
            Text(
              DateFormat('d MMM yy', 'id_ID').format(tanggal).toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: warna,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak pos: semua kartu yang pernah diterima dan dikirim.
class KotakPosPage extends ConsumerStatefulWidget {
  const KotakPosPage({super.key});

  @override
  ConsumerState<KotakPosPage> createState() => _KotakPosPageState();
}

class _KotakPosPageState extends ConsumerState<KotakPosPage> {
  bool _terkirim = false;

  @override
  Widget build(BuildContext context) {
    final daftar = ref.watch(
      _terkirim ? kartuPosTerkirimProvider : kartuPosMasukProvider,
    );

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      appBar: const BilahEkspedisi(
        judul: 'Kotak pos',
        keterangan: 'Kabar dari jalan',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Diterima')),
                ButtonSegment(value: true, label: Text('Dikirim')),
              ],
              selected: {_terkirim},
              onSelectionChanged: (p) => setState(() => _terkirim = p.first),
            ),
          ),
          Expanded(
            child: daftar.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (galat, _) => KosongHangat(
                ikon: Icons.cloud_off_rounded,
                judul: 'Kotak posnya belum bisa dibuka',
                isi: galat.toString(),
              ),
              data: (kartu) => kartu.isEmpty
                  ? KosongHangat(
                      ikon: Icons.local_post_office_outlined,
                      judul: _terkirim
                          ? 'Belum pernah mengirim'
                          : 'Belum ada kartu pos',
                      isi:
                          'Buka sebuah perjalanan, ketuk singgahan yang '
                          'berfoto, lalu kirim sebagai kartu pos ke teman.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                      itemCount: kartu.length,
                      itemBuilder: (context, i) => _KartuMini(k: kartu[i], i: i)
                          .animate(delay: (60 * i.clamp(0, 12)).ms)
                          .fadeIn(duration: TourvellaMotion.sedang)
                          .scaleXY(
                            begin: 0.85,
                            curve: TourvellaMotion.memantul,
                          ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuMini extends StatelessWidget {
  const _KartuMini({required this.k, required this.i});

  final KartuPos k;
  final int i;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Tiap kartu miring sedikit berbeda, seperti ditempel di papan.
    final miring = ((i * 37) % 7 - 3) * 0.012;

    return TourvellaPressable(
      onTap: () => context.push('/kartu-pos/${k.id}'),
      child: Transform.rotate(
        angle: miring,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: TourvellaColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        k.fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, e, s) =>
                            const ColoredBox(color: TourvellaColors.softSky),
                      ),
                    ),
                    if (k.untukSaya && !k.sudahDibaca)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: TourvellaColors.deepAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Baru',
                            style: TextStyle(
                              color: TourvellaColors.textOnDeep,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                k.tempat?.split(',').first ?? 'Dari perjalanan',
                style: text.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                k.untukSaya ? 'dari ${k.dari}' : waktuSantai(k.dibuat),
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
