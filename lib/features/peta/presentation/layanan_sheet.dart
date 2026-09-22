import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../recording/application/recording_controller.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../../trips/presentation/peta_rute.dart';
import '../data/layanan_data.dart';

/// "Bensin & bengkel": SPBU, bengkel, dan tambal ban terdekat.
///
/// Dibuka dari layar rekam — di situlah orang membutuhkannya, dengan motor
/// yang mulai tersendat atau jarum bensin yang turun.
abstract final class LayananSheet {
  static Future<void> tampilkan(
    BuildContext context, {
    JenisLayanan awal = JenisLayanan.spbu,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TourvellaColors.base,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, gulir) => _LayananIsi(awal: awal, gulir: gulir),
    ),
  );
}

class _LayananIsi extends ConsumerStatefulWidget {
  const _LayananIsi({required this.awal, required this.gulir});

  final JenisLayanan awal;
  final ScrollController gulir;

  @override
  ConsumerState<_LayananIsi> createState() => _LayananIsiState();
}

class _LayananIsiState extends ConsumerState<_LayananIsi> {
  late JenisLayanan _jenis = widget.awal;
  String? _kendaraan;
  ({double lat, double lng})? _posisi;
  HasilLayanan? _hasil;
  String? _galat;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    unawaited(_cari());
  }

  Future<({double lat, double lng})> _ambilPosisi() async {
    // Perekaman yang sedang jalan sudah punya posisi terbaru. Radio GPS
    // tidak perlu dinyalakan dua kali.
    final terakhir = ref.read(recordingControllerProvider).latest;
    if (terakhir != null) return (lat: terakhir.lat, lng: terakhir.lng);

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      throw Exception(
        'Tourvella perlu izin lokasi untuk mencari yang terdekat. '
        'Posisimu tidak disimpan.',
      );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        // Sedang, bukan tinggi: untuk mencari SPBU terdekat, puluhan meter
        // tidak mengubah jawaban, dan GPS presisi tinggi memakan baterai.
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (lat: p.latitude, lng: p.longitude);
  }

  Future<void> _cari() async {
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      _posisi ??= await _ambilPosisi();
      final hasil = await ref
          .read(layananRepositoryProvider)
          .terdekat(
            lat: _posisi!.lat,
            lng: _posisi!.lng,
            jenis: _jenis,
            kendaraan: _jenis == JenisLayanan.bengkel ? _kendaraan : null,
          );
      if (mounted) setState(() => _hasil = hasil);
    } on TourvellaException catch (e) {
      // Server menjawab, tapi menolak: pesannya sudah Bahasa Indonesia yang
      // layak dibaca — jangan ditimpa tebakan "tidak ada sinyal".
      if (mounted) setState(() => _galat = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _galat = e is Exception && e.toString().startsWith('Exception: ')
              ? e.toString().substring(11)
              : 'Belum bisa mencari. Sepertinya tidak ada sinyal, dan wilayah '
                    'ini belum diunduh untuk dipakai offline.',
        );
      }
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _ganti(JenisLayanan j) {
    if (j == _jenis) return;
    HapticFeedback.selectionClick();
    setState(() => _jenis = j);
    unawaited(_cari());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasil = _hasil;

    return CustomScrollView(
      controller: widget.gulir,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TourvellaColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Di sekitarmu', style: text.titleLarge),
                    const Spacer(),
                    if (hasil?.dariOffline ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TourvellaColors.warmNeutral,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: TourvellaColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text('Data offline', style: text.labelSmall),
                          ],
                        ),
                      ).animate().fadeIn().scaleXY(begin: 0.8),
                  ],
                ),
                const SizedBox(height: 12),
                _PemilihJenis(pilihan: _jenis, onGanti: _ganti),
                if (_jenis == JenisLayanan.bengkel) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (k, label) in [
                        (null, 'Semua'),
                        ('motor', 'Motor'),
                        ('mobil', 'Mobil'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _kendaraan == k,
                          onSelected: (_) {
                            setState(() => _kendaraan = k);
                            unawaited(_cari());
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (_memuat)
          const SliverToBoxAdapter(child: _Mencari())
        else if (_galat != null)
          SliverToBoxAdapter(
            child: KosongHangat(
              ikon: Icons.wrong_location_outlined,
              judul: 'Belum ketemu',
              isi: _galat!,
              aksi: TextButton(
                onPressed: () => context.push('/peta-offline'),
                child: const Text('Unduh peta offline'),
              ),
            ),
          )
        else if (hasil == null || hasil.daftar.isEmpty)
          SliverToBoxAdapter(
            child: KosongHangat(
              ikon: Icons.search_off_rounded,
              judul: 'Tidak ada ${_jenis.label.toLowerCase()} dalam 25 km',
              isi:
                  'Datanya dari OpenStreetMap, dan belum semua tempat '
                  'tercatat. Tanya warga sekitar juga, ya.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList.builder(
              itemCount: hasil.daftar.length + 1,
              itemBuilder: (context, i) {
                if (i == hasil.daftar.length) return const _Atribusi();
                return _BarisLayanan(
                      l: hasil.daftar[i],
                      terdekat: i == 0,
                      dari: _posisi!,
                    )
                    .animate(delay: (45 * i.clamp(0, 10)).ms)
                    .fadeIn(duration: TourvellaMotion.sedang)
                    .slideY(begin: 0.12, curve: TourvellaMotion.mengalir);
              },
            ),
          ),
      ],
    );
  }
}

class _PemilihJenis extends StatelessWidget {
  const _PemilihJenis({required this.pilihan, required this.onGanti});

  final JenisLayanan pilihan;
  final ValueChanged<JenisLayanan> onGanti;

  static const _ikon = {
    JenisLayanan.spbu: Icons.local_gas_station_rounded,
    JenisLayanan.bengkel: Icons.build_rounded,
    JenisLayanan.tambalBan: Icons.tire_repair_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TourvellaColors.softSky.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, batas) {
          final lebar = batas.maxWidth / JenisLayanan.values.length;
          final indeks = JenisLayanan.values.indexOf(pilihan);
          return Stack(
            children: [
              // Penanda pilihan meluncur, bukan melompat.
              AnimatedPositioned(
                duration: TourvellaMotion.sedang,
                curve: TourvellaMotion.memantul,
                left: indeks * lebar,
                width: lebar,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: TourvellaColors.textPrimary.withValues(
                          alpha: 0.06,
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final j in JenisLayanan.values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onGanti(j),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              Icon(
                                _ikon[j],
                                size: 20,
                                color: j == pilihan
                                    ? TourvellaColors.deepAccent
                                    : TourvellaColors.textSecondary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                j.label,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: j == pilihan
                                          ? TourvellaColors.textPrimary
                                          : TourvellaColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BarisLayanan extends StatelessWidget {
  const _BarisLayanan({
    required this.l,
    required this.terdekat,
    required this.dari,
  });

  final Layanan l;
  final bool terdekat;
  final ({double lat, double lng}) dari;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final arah = l.arah ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TourvellaPressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _PetaTempat(l: l, dari: dari),
          ),
        ),
        skala: 0.985,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: terdekat
                ? Border.all(color: TourvellaColors.ember, width: 1.4)
                : null,
          ),
          child: Row(
            children: [
              // Kompas kecil: panahnya menunjuk ke tempat itu, dengan utara
              // di atas. Berputar masuk saat muncul.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: TourvellaColors.softSky,
                  shape: BoxShape.circle,
                  border: Border.all(color: TourvellaColors.divider),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 3,
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: TourvellaColors.textSecondary,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: arah - 120, end: arah),
                      duration: TourvellaMotion.lambat,
                      curve: TourvellaMotion.memantul,
                      builder: (context, a, anak) => Transform.rotate(
                        angle: a * math.pi / 180,
                        child: anak,
                      ),
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 22,
                        color: terdekat
                            ? TourvellaColors.ember
                            : TourvellaColors.deepAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.nama,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (l.jarakM != null)
                          '${teksJarak(l.jarakM!)} ke ${namaArah(arah)}',
                        if (l.buka24Jam) 'buka 24 jam',
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                    if (terdekat)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: const LabelKapital(
                          'Paling dekat',
                          warna: TourvellaColors.ember,
                          ukuran: 9,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: TourvellaColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu tempat di peta: posisimu, tempatnya, dan garis lurus di antaranya.
class _PetaTempat extends StatelessWidget {
  const _PetaTempat({required this.l, required this.dari});

  final Layanan l;
  final ({double lat, double lng}) dari;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BilahEkspedisi(
        judul: l.nama,
        keterangan: l.jarakM == null
            ? null
            : '${teksJarak(l.jarakM!)} ke ${namaArah(l.arah ?? 0)}',
      ),
      body: Column(
        children: [
          Expanded(
            child: PetaRute(
              jalur: [
                JalurRute(
                  id: 'menuju',
                  titik: [LatLng(dari.lat, dari.lng), LatLng(l.lat, l.lng)],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              18 + MediaQuery.of(context).padding.bottom,
            ),
            color: TourvellaColors.base,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.nama, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  [
                    if (l.jarakM != null)
                      '${teksJarak(l.jarakM!)} garis lurus ke ${namaArah(l.arah ?? 0)}',
                    if (l.merek != null) l.merek!,
                  ].join(' · '),
                  style: text.bodyMedium,
                ),
                if (l.jamBuka != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.buka24Jam ? 'Buka 24 jam' : l.jamBuka!,
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (l.telepon != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: l.telepon!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomornya tersalin.')),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l.telepon!,
                          style: text.bodySmall?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Jaraknya garis lurus, bukan lewat jalan. Ikuti papan '
                  'petunjuk dan tanya warga sekitar.',
                  style: text.bodySmall?.copyWith(
                    color: TourvellaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mencari extends StatelessWidget {
  const _Mencari();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          // Riak radar yang mengembang: sedang mencari di sekitar.
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TourvellaColors.deepAccent,
                            width: 2,
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(), delay: (400 * i).ms)
                      .scaleXY(begin: 0.2, end: 1, duration: 1400.ms)
                      .fadeOut(duration: 1400.ms),
                const Icon(
                  Icons.my_location_rounded,
                  color: TourvellaColors.deepAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mencari di sekitarmu…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Atribusi extends StatelessWidget {
  const _Atribusi();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Data © kontributor OpenStreetMap. Posisimu dikasarkan sebelum '
        'dikirim dan tidak disimpan.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
