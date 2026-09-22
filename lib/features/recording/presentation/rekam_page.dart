import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/theme/tourvella_theme.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../groups/application/live_location_controller.dart';
import '../../intercom/application/intercom_controller.dart';
import '../../intercom/presentation/telepon_rombongan.dart';
import '../../navigasi/application/navigasi_controller.dart';
import '../../navigasi/presentation/panel_navigasi.dart';
import '../../peta/presentation/layanan_sheet.dart';
import '../../trips/data/trip_models.dart';
import '../../trips/presentation/peta_rute.dart';
import '../application/susur_ulang.dart';
import '../application/recording_controller.dart';
import '../data/photo_uploader.dart';

/// Layar perjalanan yang sedang berjalan.
///
/// Dirancang untuk dilihat sekilas — di atas motor, sambil berhenti di lampu
/// merah, dengan sarung tangan. Karena itu angkanya besar, tombolnya sedikit,
/// dan tidak ada satu pun hal yang perlu dibaca teliti.
///
/// Petanya dibuat sekali lalu diberi titik baru lewat controller, bukan
/// dibangun ulang tiap posisi masuk. Membangun ulang MapLibre tiap 30 detik
/// selama enam jam akan menghabiskan baterai persis di saat perjalanan sedang
/// berlangsung.
class RekamPage extends ConsumerStatefulWidget {
  const RekamPage({super.key});

  @override
  ConsumerState<RekamPage> createState() => _RekamPageState();
}

class _RekamPageState extends ConsumerState<RekamPage> {
  static const _jalurSesi = 'sesi';
  static const _jalurLama = 'lama';
  static const _jalurNavigasi = 'navigasi';

  final _peta = PetaRuteController();
  Timer? _detak;
  Duration _berjalan = Duration.zero;

  @override
  void initState() {
    super.initState();
    _mulaiDetak();
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  /// Penghitung waktu jalan sendiri tiap detik. Tidak menunggu titik GPS baru —
  /// berhenti lama di rest area tetap terhitung sebagai bagian perjalanan.
  void _mulaiDetak() {
    _detak = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _berjalan += const Duration(seconds: 1));
    });
  }

  Future<void> _selesai() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TourvellaColors.base,
        title: const Text('Tutup perjalanan?'),
        content: const Text(
          'Jejak yang belum terkirim akan disusulkan dulu. Setelah ditutup, '
          'perjalanan ini tidak bisa dilanjutkan lagi.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut jalan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    // Perjalanan yang ditutup tidak punya ruang suara lagi — mikrofon tidak
    // boleh tetap tersambung ke sesuatu yang sudah selesai.
    final tripId = ref.read(recordingControllerProvider).tripId;
    if (ref.read(intercomControllerProvider).tripId == tripId) {
      await ref.read(intercomControllerProvider.notifier).keluar();
    }

    // Begitu juga panduan suaranya: perjalanan selesai, tidak ada lagi yang
    // perlu dipandu, dan GPS rapat untuk navigasi tidak perlu terus menyala.
    if (ref.read(navigasiControllerProvider).aktif) {
      await ref.read(navigasiControllerProvider.notifier).berhenti();
    }

    await ref.read(recordingControllerProvider.notifier).stop();
    if (!mounted) return;
    context.go('/');
  }

  /// Tandai singgahan: catatan, foto, atau dua-duanya.
  ///
  /// Foto dan catatan disatukan dalam satu lembar, bukan dua alur terpisah.
  /// Saat orang berhenti, yang terjadi di kepalanya satu hal — "ini perlu
  /// diingat" — bukan dua keputusan terpisah soal media apa yang dipakai.
  Future<void> _catat() async {
    final controller = TextEditingController();
    XFile? foto;

    final simpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> ambil(String sumber) async {
            final pengunggah = ref.read(photoUploaderProvider);
            final hasil = switch (sumber) {
              'foto' => await pengunggah.dariKamera(),
              'video' => await pengunggah.videoDariKamera(),
              _ => await pengunggah.dariGaleri(),
            };
            if (hasil != null) setSheetState(() => foto = hasil);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ada apa di sini?',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                AnimatedSize(
                  duration: TourvellaMotion.sedang,
                  curve: TourvellaMotion.mengalir,
                  child: foto == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                if (PhotoUploader.apakahVideo(foto!))
                                  // Tanpa pemutar di sini: lembar ini dibuka
                                  // di pinggir jalan, dan yang perlu dipastikan
                                  // cuma bahwa videonya sudah tertangkap.
                                  Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: TourvellaColors.routeGradient,
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 48,
                                          color: TourvellaColors.textOnDeep,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Video siap disimpan',
                                          style: TextStyle(
                                            color: TourvellaColors.textOnDeep,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Image.file(
                                    File(foto!.path),
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: TourvellaPressable(
                                    skala: 0.85,
                                    onTap: () =>
                                        setSheetState(() => foto = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: TourvellaColors.base.withValues(
                                          alpha: 0.92,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: TourvellaColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                TextField(
                  controller: controller,
                  autofocus: foto == null,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Berhenti makan soto di pinggir jalan',
                  ),
                ),
                const SizedBox(height: 16),

                if (foto == null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ambil('foto'),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 19,
                          ),
                          label: const Text('Foto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ambil('video'),
                          icon: const Icon(Icons.videocam_outlined, size: 19),
                          label: const Text('Video'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ambil('galeri'),
                          icon: const Icon(Icons.image_outlined, size: 19),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
                if (foto == null) const SizedBox(height: 12),

                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Simpan singgahan'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (simpan != true) return;
    await ref
        .read(recordingControllerProvider.notifier)
        .addNote(controller.text, foto: foto);
  }

  @override
  Widget build(BuildContext context) {
    final rekaman = ref.watch(recordingControllerProvider);
    final belumTerkirim = ref.watch(pendingPointCountProvider).value ?? 0;

    // Titik baru ditempelkan ke garis yang sudah ada. Tidak ada setState di
    // sini, jadi petanya tidak ikut dibangun ulang.
    ref.listen(recordingControllerProvider.select((s) => s.latest), (
      _,
      terbaru,
    ) {
      if (terbaru == null) return;
      _peta.tambahTitik(_jalurSesi, LatLng(terbaru.lat, terbaru.lng));
    });

    if (!rekaman.isRecording) {
      return const _TidakSedangMerekam();
    }

    // Rute navigasi digambar di peta, dan digambar ulang sendiri kalau
    // rutenya dihitung ulang karena keluar jalur.
    ref.listen(navigasiControllerProvider.select((s) => s.rute), (_, rute) {
      _peta.gantiJalur(
        _jalurNavigasi,
        [for (final t in rute?.garis ?? const []) LatLng(t.lat, t.lng)],
        warna: '#A8C8E8',
      );
    });

    // Trip Bareng: rombongan ikut tampil di peta yang dilihat sambil jalan,
    // bukan hanya di layar Trip Bareng yang jarang dibuka di atas motor.
    final tripId = rekaman.tripId!;
    if (rekaman.bareng) {
      ref.watch(liveLocationControllerProvider(tripId));
      ref.listen(
        liveLocationControllerProvider(tripId).select((s) => s.posisi),
        (_, posisi) {
          final warna = {
            for (final m in ref.read(memberListProvider(tripId)).value ??
                const <TripMember>[])
              m.userId: m.routeColor,
          };
          _peta.perbaruiPosisiLangsung(posisi.values, warna);
        },
      );
      ref.watch(memberListProvider(tripId));
    }

    // Seluruh layar rekam bertema malam: ini layar yang dibuka saat
    // berangkat subuh dan dilihat sambil jalan, bukan layar yang dibaca
    // sambil duduk.
    return Theme(
      data: TourvellaTheme.gelap(),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: PetaRute(
                controller: _peta,
                // Tanpa kendaraan dari garasi dan sebelum kecepatannya
                // terbaca, anggap motor: untuk siapa aplikasi ini dibuat.
                kendaraan: {
                  _jalurSesi: ModaPenanda.dari(rekaman.moda ?? 'motor'),
                },
                jalur: [
                  // Rute lama digambar lebih dulu supaya berada di bawah, dan
                  // dengan warna pastel muda — ini bayangan masa lalu, bukan
                  // jejak yang sedang kamu buat.
                  if (rekaman.jejakLama.isNotEmpty)
                    JalurRute(
                      id: _jalurLama,
                      warna: '#A8C8E8',
                      titik: [
                        for (final t in rekaman.jejakLama) LatLng(t.lat, t.lng),
                      ],
                    ),
                  JalurRute(
                    id: _jalurSesi,
                    titik: [
                      for (final t in rekaman.jejak) LatLng(t.lat, t.lng),
                    ],
                  ),
                ],
              ),
            ),

            // Peta memenuhi layar, jadi panel dibuat mengambang di atasnya —
            // bukan memotongnya jadi kotak-kotak.
            SafeArea(
              child: Column(
                children: [
                  _PanelAtas(
                    judul: rekaman.title ?? 'Perjalanan',
                    belumTerkirim: belumTerkirim,
                  ),
                  const PanelNavigasi(),
                  const Spacer(),
                  if (rekaman.susurUlang != null)
                    _KartuSusurUlang(
                      lama: rekaman.jejakLama,
                      judulLama: rekaman.susurUlang!.title,
                      sudahBerjalan: _berjalan,
                      jarakM: rekaman.jarakM,
                      posisiSekarang: rekaman.latest == null
                          ? null
                          : (
                              lat: rekaman.latest!.lat,
                              lng: rekaman.latest!.lng,
                            ),
                    ),
                  if (rekaman.bareng)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: PanelTelepon(tripId: tripId, judul: rekaman.title),
                    ),
                  _PanelBawah(
                    berjalan: _berjalan,
                    jejak: rekaman.recordedCount,
                    jarakM: rekaman.jarakM,
                    onCatat: _catat,
                    onSelesai: _selesai,
                    onLayanan: () => LayananSheet.tampilkan(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelAtas extends StatelessWidget {
  const _PanelAtas({required this.judul, required this.belumTerkirim});

  final String judul;
  final int belumTerkirim;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
            decoration: BoxDecoration(
              color: TourvellaColors.base.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: TourvellaColors.textPrimary.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                TourvellaPressable(
                  skala: 0.9,
                  onTap: () => context.go('/'),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: TourvellaColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const TitikBerdenyut(
                  warna: TourvellaColors.deepAccent,
                  ukuran: 8,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sedang merekam', style: text.labelMedium),
                      Text(
                        judul,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Muncul sendiri hanya kalau ada yang tertahan, lalu hilang lagi
          // begitu terkirim. Tidak perlu ada ruang kosong menunggunya.
          AnimatedSize(
            duration: TourvellaMotion.sedang,
            curve: TourvellaMotion.mengalir,
            child: belumTerkirim == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: TourvellaColors.warmNeutral.withValues(
                          alpha: 0.95,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 15,
                            color: TourvellaColors.deepAccent,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            '$belumTerkirim jejak menunggu sinyal',
                            style: text.bodySmall?.copyWith(
                              color: TourvellaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelBawah extends StatelessWidget {
  const _PanelBawah({
    required this.berjalan,
    required this.jejak,
    required this.jarakM,
    required this.onCatat,
    required this.onSelesai,
    required this.onLayanan,
  });

  final Duration berjalan;
  final int jejak;
  final double jarakM;
  final VoidCallback onCatat;
  final VoidCallback onSelesai;
  final VoidCallback onLayanan;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TourvellaColors.malam.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: TourvellaColors.kontur.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Kontur di latar panel: permukaan gelap polos terbaca seperti
          // kotak hitam; kontur membuatnya terbaca sebagai peta.
          Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.22, jumlahGaris: 5, benih: 11),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              children: [
                // Jarak diberi tempat paling besar dan diputar seperti odometer.
                // Inilah angka yang sebenarnya ditunggu orang saat merekam.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Odometer(
                      nilai: jarakM / 1000,
                      desimal: 1,
                      satuan: 'KM',
                      gaya: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: TourvellaColors.ember,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const LabelKapital('Berjalan'),
                        const SizedBox(height: 2),
                        Text(
                          _jam(berjalan),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const LabelKapital('Jejak'),
                        const SizedBox(height: 2),
                        Text(
                          '$jejak',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const PemisahJalur(warna: TourvellaColors.kontur),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCatat,
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Catatan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // SPBU dan bengkel terdekat — satu ketukan, karena yang
                    // membutuhkannya biasanya sedang menepi dengan tergesa.
                    IconButton.filledTonal(
                      tooltip: 'Bensin & bengkel terdekat',
                      onPressed: onLayanan,
                      style: IconButton.styleFrom(
                        backgroundColor: TourvellaColors.softSky,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(
                        Icons.local_gas_station_rounded,
                        color: TourvellaColors.deepAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onSelesai,
                        icon: const Icon(Icons.stop_rounded, size: 20),
                        label: const Text('Selesai'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _jam(Duration d) {
    final j = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final dt = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$j:$m:$dt' : '$m:$dt';
  }
}

class _TidakSedangMerekam extends StatelessWidget {
  const _TidakSedangMerekam();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 44,
                  color: TourvellaColors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Tidak ada perjalanan yang sedang berjalan',
                  style: text.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pushReplacement('/rekam/mulai'),
                  child: const Text('Mulai perjalanan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Perbandingan dengan perjalanan yang sedang disusuri ulang.
///
/// Yang ditampilkan bukan lomba. Kalimatnya sengaja tenang dan tidak pernah
/// memuji atau menyalahkan — susur ulang itu mengingat, bukan mengalahkan
/// diri sendiri yang dulu.
class _KartuSusurUlang extends StatelessWidget {
  const _KartuSusurUlang({
    required this.lama,
    required this.judulLama,
    required this.sudahBerjalan,
    required this.jarakM,
    required this.posisiSekarang,
  });

  final List<JejakLama> lama;
  final String judulLama;
  final Duration sudahBerjalan;
  final double jarakM;
  final ({double lat, double lng})? posisiSekarang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final hasil = bandingkan(
      lama: lama,
      sudahBerjalan: sudahBerjalan,
      jarakSekarangM: jarakM,
      posisiSekarang: posisiSekarang,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: TourvellaColors.warmNeutral.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: TourvellaColors.textPrimary.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: TourvellaColors.deepAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menyusuri ulang $judulLama',
                    style: text.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(kalimatSelisih(hasil.selisih), style: text.titleMedium),

            // Catatan lama muncul sendiri saat kamu lewat tempat yang sama.
            // Inilah bagian yang paling terasa seperti susur ulang sungguhan.
            AnimatedSize(
              duration: TourvellaMotion.sedang,
              curve: TourvellaMotion.mengalir,
              child: hasil.catatanTerdekat == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            size: 15,
                            color: TourvellaColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dulu di sini: ${hasil.catatanTerdekat}',
                              style: text.bodySmall,
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
