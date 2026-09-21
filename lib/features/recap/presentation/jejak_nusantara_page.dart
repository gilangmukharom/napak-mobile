import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../sosial/data/sosial_models.dart';
import '../../sosial/data/sosial_repository.dart';
import '../../sosial/presentation/komponen_sosial.dart';

/// Jejak Nusantara.
///
/// Seratus delapan puluh delapan kota digambar sebagai titik, dan bentuk
/// kepulauannya muncul sendiri dari sebaran titik itu — tanpa satu garis
/// pantai pun, tanpa peta dari pihak mana pun. Kota yang pernah dilewati
/// menyala satu per satu dari barat ke timur, seperti matahari terbit
/// menyapu Nusantara.
///
/// Bukan papan peringkat, dan tidak ada yang dibandingkan dengan orang lain.
/// Provinsi yang belum pernah didatangi ditampilkan sebagai kemungkinan,
/// bukan daftar tugas.
class JejakNusantaraPage extends ConsumerWidget {
  const JejakNusantaraPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jejak = ref.watch(jejakNusantaraProvider);

    return Scaffold(
      backgroundColor: NapakColors.textPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: NapakColors.textOnDeep,
        title: const Text('Jejak Nusantara'),
        actions: [
          if (jejak.value != null)
            IconButton(
              tooltip: 'Bagikan',
              onPressed: () {
                final j = jejak.value!;
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Jejak Nusantara-ku: ${j.provinsiTerjejak} dari '
                        '${j.totalProvinsi} provinsi, ${j.kotaTerjejak} kota. '
                        'Direkam pakai Napak.',
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: jejak.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NapakColors.primary),
        ),
        error: (galat, _) => KosongHangat(
          ikon: Icons.map_outlined,
          judul: 'Petanya belum bisa digambar',
          isi: galat.toString(),
        ),
        data: (j) => ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _Angka(j: j),
            const SizedBox(height: 8),
            _PetaRasi(titik: j.titik),
            const SizedBox(height: 8),
            _DaftarProvinsi(j: j),
          ],
        ),
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.j});

  final JejakNusantara j;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gayaBesar = text.displayMedium?.copyWith(
      color: NapakColors.textOnDeep,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AngkaBerjalan(
                nilai: j.provinsiTerjejak.toDouble(),
                desimal: 0,
                gaya: gayaBesar,
              ),
              Text(
                ' / ${j.totalProvinsi}',
                style: text.headlineSmall?.copyWith(
                  color: NapakColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'provinsi',
                style: text.titleMedium?.copyWith(
                  color: NapakColors.textOnDeep.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          Text(
            '${j.kotaTerjejak} dari ${j.totalKota} kota pernah kamu lewati',
            style: text.bodyMedium?.copyWith(
              color: NapakColors.textOnDeep.withValues(alpha: 0.7),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 14),
          // Bilah Nusantara: berapa bagian yang sudah tersentuh.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: j.totalProvinsi == 0
                    ? 0
                    : j.provinsiTerjejak / j.totalProvinsi,
              ),
              duration: const Duration(milliseconds: 1600),
              curve: NapakMotion.mengalir,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 6,
                backgroundColor: NapakColors.textOnDeep.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(NapakColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peta rasi bintang: tiap kota satu titik.
class _PetaRasi extends StatefulWidget {
  const _PetaRasi({required this.titik});

  final List<TitikKota> titik;

  @override
  State<_PetaRasi> createState() => _PetaRasiState();
}

class _PetaRasiState extends State<_PetaRasi> with TickerProviderStateMixin {
  /// Sapuan fajar dari barat ke timur — sekali, saat halaman dibuka.
  late final AnimationController _fajar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  /// Kerlip pelan yang terus berjalan setelahnya.
  late final AnimationController _kerlip = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  TitikKota? _dipilih;

  // Kotak Nusantara: dari Sabang sampai Merauke, dari Miangas sampai Rote.
  static const _barat = 94.5;
  static const _timur = 141.5;
  static const _utara = 6.5;
  static const _selatan = -11.5;

  @override
  void dispose() {
    _fajar.dispose();
    _kerlip.dispose();
    super.dispose();
  }

  Offset _proyeksi(TitikKota t, Size ukuran) => Offset(
    (t.lng - _barat) / (_timur - _barat) * ukuran.width,
    (_utara - t.lat) / (_utara - _selatan) * ukuran.height,
  );

  void _ketuk(Offset posisi, Size ukuran) {
    TitikKota? terdekat;
    var jarak = double.infinity;
    for (final t in widget.titik) {
      final d = (_proyeksi(t, ukuran) - posisi).distance;
      if (d < jarak) {
        jarak = d;
        terdekat = t;
      }
    }
    if (terdekat != null && jarak < 26) {
      HapticFeedback.selectionClick();
      setState(() => _dipilih = terdekat);
    } else {
      setState(() => _dipilih = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: (_timur - _barat) / (_utara - _selatan) * 0.92,
          child: LayoutBuilder(
            builder: (context, batas) {
              final ukuran = Size(batas.maxWidth, batas.maxHeight);
              return GestureDetector(
                onTapUp: (d) => _ketuk(d.localPosition, ukuran),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fajar, _kerlip]),
                  builder: (context, _) => CustomPaint(
                    size: ukuran,
                    painter: _PelukisRasi(
                      titik: widget.titik,
                      proyeksi: (t) => _proyeksi(t, ukuran),
                      fajar: Curves.easeInOut.transform(_fajar.value),
                      kerlip: _kerlip.value,
                      dipilih: _dipilih,
                      barat: _barat,
                      timur: _timur,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: AnimatedSwitcher(
            duration: NapakMotion.cepat,
            child: _dipilih == null
                ? Text(
                    'Ketuk sebuah titik untuk melihat namanya',
                    key: const ValueKey('petunjuk'),
                    style: text.bodySmall?.copyWith(
                      color: NapakColors.textOnDeep.withValues(alpha: 0.5),
                    ),
                  )
                : Container(
                    key: ValueKey(_dipilih!.nama),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _dipilih!.sudah
                          ? NapakColors.primary
                          : NapakColors.textOnDeep.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_dipilih!.nama} · ${_dipilih!.provinsi}'
                      '${_dipilih!.sudah ? '' : ' — belum'}',
                      style: text.labelLarge?.copyWith(
                        color: _dipilih!.sudah
                            ? NapakColors.textPrimary
                            : NapakColors.textOnDeep,
                      ),
                    ),
                  ).animate().scaleXY(begin: 0.8, curve: NapakMotion.memantul),
          ),
        ),
      ],
    );
  }
}

class _PelukisRasi extends CustomPainter {
  _PelukisRasi({
    required this.titik,
    required this.proyeksi,
    required this.fajar,
    required this.kerlip,
    required this.dipilih,
    required this.barat,
    required this.timur,
  });

  final List<TitikKota> titik;
  final Offset Function(TitikKota) proyeksi;
  final double fajar;
  final double kerlip;
  final TitikKota? dipilih;
  final double barat;
  final double timur;

  @override
  void paint(Canvas canvas, Size size) {
    final redup = Paint()
      ..color = NapakColors.textOnDeep.withValues(alpha: 0.16);
    final garis = Paint()
      ..color = NapakColors.primary.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    // Garis fajar yang menyapu dari barat ke timur.
    final xFajar = fajar * size.width;
    if (fajar < 1) {
      final sapuan = Rect.fromLTWH(xFajar - 60, 0, 60, size.height);
      canvas.drawRect(
        sapuan,
        Paint()
          ..shader = LinearGradient(
            colors: [
              NapakColors.primary.withValues(alpha: 0),
              NapakColors.primary.withValues(alpha: 0.18),
            ],
          ).createShader(sapuan),
      );
    }

    // Garis tipis antar kota yang sudah dijejak dalam satu provinsi —
    // rasi bintangnya.
    final perProvinsi = <String, List<Offset>>{};
    for (final t in titik) {
      if (!t.sudah) continue;
      final p = proyeksi(t);
      if (p.dx > xFajar) continue;
      perProvinsi.putIfAbsent(t.provinsi, () => []).add(p);
    }
    for (final daftar in perProvinsi.values) {
      daftar.sort((a, b) => a.dx.compareTo(b.dx));
      for (var i = 0; i + 1 < daftar.length; i++) {
        canvas.drawLine(daftar[i], daftar[i + 1], garis);
      }
    }

    for (final t in titik) {
      final p = proyeksi(t);
      final menyala = t.sudah && p.dx <= xFajar;

      if (!menyala) {
        canvas.drawCircle(p, 1.8, redup);
        continue;
      }

      // Tiap bintang berkerlip dengan fasenya sendiri, diambil dari posisinya,
      // supaya tidak berdenyut serempak seperti lampu hias.
      final fase = (kerlip + (t.lng * 0.37 + t.lat * 0.11)) % 1;
      final denyut = 0.5 + 0.5 * math.sin(fase * 2 * math.pi);

      // Baru saja tersapu fajar: sempat membesar sebentar.
      final sejakMenyala = ((xFajar - p.dx) / 80).clamp(0.0, 1.0);
      final letupan = 1 + (1 - sejakMenyala) * 1.4;

      canvas
        ..drawCircle(
          p,
          (7 + denyut * 4) * letupan,
          Paint()
            ..color = NapakColors.primary.withValues(alpha: 0.12 + denyut * 0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..drawCircle(p, 3.2 * letupan, Paint()..color = NapakColors.primary)
        ..drawCircle(p, 1.4, Paint()..color = NapakColors.textOnDeep);
    }

    final pilih = dipilih;
    if (pilih != null) {
      final p = proyeksi(pilih);
      canvas.drawCircle(
        p,
        10,
        Paint()
          ..color = NapakColors.textOnDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisRasi lama) =>
      lama.fajar != fajar ||
      lama.kerlip != kerlip ||
      lama.dipilih != dipilih ||
      lama.titik != titik;
}

class _DaftarProvinsi extends StatelessWidget {
  const _DaftarProvinsi({required this.j});

  final JejakNusantara j;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final putih = NapakColors.textOnDeep;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: NapakColors.base,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Provinsi yang pernah kamu injak', style: text.titleMedium),
          const SizedBox(height: 14),
          for (var i = 0; i < j.sudah.length; i++)
            MunculBertahap(
              indeks: i,
              child: _BarisProvinsi(p: j.sudah[i], urutan: i),
            ),
          if (j.belum.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Masih menunggu', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bukan daftar tugas. Sekadar pengingat bahwa Nusantara masih '
              'luas.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < j.belum.length; i++)
                  Chip(
                        label: Text(j.belum[i]),
                        backgroundColor: NapakColors.softSky.withValues(
                          alpha: 0.6,
                        ),
                        side: BorderSide.none,
                        labelStyle: text.labelMedium?.copyWith(
                          color: NapakColors.textSecondary,
                        ),
                      )
                      .animate(delay: (25 * i).ms)
                      .fadeIn(duration: NapakMotion.cepat)
                      .scaleXY(begin: 0.8, curve: NapakMotion.memantul),
              ],
            ),
          ],
          if (j.sudah.isEmpty)
            Text(
              'Rekam perjalanan pertamamu, dan titik pertamanya akan menyala '
              'di sini.',
              style: text.bodyMedium?.copyWith(color: putih),
            ),
        ],
      ),
    );
  }
}

class _BarisProvinsi extends StatelessWidget {
  const _BarisProvinsi({required this.p, required this.urutan});

  final ProvinsiTerjejak p;
  final int urutan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.nama, style: text.titleSmall)),
              Text(
                '${p.kota.length}/${p.totalKota}',
                style: text.labelLarge?.copyWith(
                  color: NapakColors.deepAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p.porsi),
              duration: Duration(milliseconds: 900 + urutan * 120),
              curve: NapakMotion.mengalir,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 8,
                backgroundColor: NapakColors.softSky,
                valueColor: const AlwaysStoppedAnimation(
                  NapakColors.deepAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              p.kota.take(4).join(', '),
              if (p.kota.length > 4) '+${p.kota.length - 4} lagi',
              if (p.pertama != null) 'sejak ${p.pertama!.year}',
            ].join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
