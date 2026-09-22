import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/theme/tourvella_theme.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../garasi/data/garasi_data.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../groups/data/simulasi_data.dart';
import '../../navigasi/application/navigasi_controller.dart';
import '../../navigasi/data/navigasi_data.dart';
import '../../navigasi/presentation/pilih_tujuan_sheet.dart';
import '../../trips/data/trip_models.dart';
import '../../trips/presentation/penanda_kendaraan.dart';
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
  Trip? _yangDisusuri;
  bool _memulai = false;

  @override
  void dispose() {
    _judul.dispose();
    super.dispose();
  }

  /// Kendaraan dari garasi yang dibawa kali ini. Boleh kosong.
  String? _kendaraanId;

  /// Jenis kendaraan: ikon di peta dan yang dilihat rombongan. Motor bawaan
  /// — untuk siapa aplikasi ini dibuat.
  ModaPenanda _moda = ModaPenanda.motor;

  /// Mulai Trip Bareng sekalian dengan rombongan simulasi (pengembangan).
  bool _simulasi = false;

  /// Tujuan yang mau dipandu dengan suara. Boleh kosong — merekam jejak
  /// tidak pernah mewajibkan tahu mau ke mana.
  Tujuan? _tujuan;

  Future<void> _mulai() async {
    setState(() => _memulai = true);

    final judul = _judul.text.trim().isEmpty
        ? 'Perjalanan ${DateFormat('d MMMM', 'id_ID').format(DateTime.now())}'
        : _judul.text.trim();

    await ref
        .read(recordingControllerProvider.notifier)
        .start(
          title: judul,
          mode: _mode,
          yangDisusuri: _yangDisusuri,
          kendaraanId: _kendaraanId,
          modaKendaraan: _moda.wire,
        );

    if (!mounted) return;
    final state = ref.read(recordingControllerProvider);
    setState(() => _memulai = false);

    if (state.isRecording) {
      // Rombongan simulasi dinyalakan setelah perjalanannya ada, karena
      // rekan palsunya bergabung ke perjalanan itu.
      if (_simulasi && _mode == TripMode.group && state.tripId != null) {
        try {
          await ref.read(simulasiRepositoryProvider).mulai(state.tripId!);
        } catch (_) {
          // Gagal menyalakan simulasi tidak boleh menggagalkan perjalanan
          // sungguhan yang sudah terlanjur dimulai.
        }
        if (!mounted) return;
      }

      final tujuan = _tujuan;
      if (tujuan != null) {
        // Rutenya dihitung dari posisi terakhir yang sudah dibaca perekam,
        // jadi tidak perlu membangunkan GPS untuk kedua kalinya.
        unawaited(_mulaiPandu(tujuan));
      }

      // Menggantikan layar ini, bukan menumpuk — menekan kembali dari layar
      // perekaman semestinya pulang ke beranda, bukan kembali ke sini.
      context.pushReplacement('/rekam');
    } else if (state.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message!)));
    }
  }

  /// Menghitung rute lalu menyalakan panduan suara.
  Future<void> _mulaiPandu(Tujuan tujuan) async {
    try {
      final posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final rute = await ref
          .read(navigasiRepositoryProvider)
          .hitung(
            dariLat: posisi.latitude,
            dariLng: posisi.longitude,
            ke: tujuan,
          );
      await ref.read(navigasiControllerProvider.notifier).mulai(rute);
    } catch (error) {
      if (!mounted) return;
      // Perjalanannya tetap terekam; yang gagal cuma panduannya.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Panduan ke ${tujuan.nama} gagal: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Menekan tombol bara di bilah bawah membawa ke sini, dan dari sini ke
    // layar rekam yang juga gelap. Halaman terang di tengahnya akan terasa
    // seperti keluar sebentar lalu masuk lagi.
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
                  colors: TourvellaColors.kanvasMalam,
                ),
              ),
            ),
            const IgnorePointer(
              child: KonturTopografi(opasitas: 0.22, benih: 17),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.3,
                child: SiluetGunung(
                  warna: [TourvellaColors.malamNaik, TourvellaColors.malam],
                ),
              ),
            ),
            const ButiranKertas(opasitas: 0.045),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: TourvellaColors.base.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        const LabelKapital(
                          'Perjalanan baru',
                          warna: TourvellaColors.emberRedup,
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
                          child: SizedBox(height: 64, child: _GarisPembuka()),
                        ),
                        const SizedBox(height: 28),
                        MunculBertahap(
                          indeks: 1,
                          child: Text(
                            'Mau ke mana?',
                            style: text.displaySmall?.copyWith(
                              color: TourvellaColors.base,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MunculBertahap(
                          indeks: 2,
                          child: Text(
                            'Tourvella akan merekam diam-diam sampai kamu bilang selesai. '
                            'Layar boleh dimatikan.',
                            style: text.bodyLarge?.copyWith(
                              color: TourvellaColors.base.withValues(
                                alpha: 0.65,
                              ),
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
                            style: text.titleLarge?.copyWith(
                              color: TourvellaColors.base,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: TourvellaColors.malamNaik.withValues(
                                alpha: 0.8,
                              ),
                              hintText: 'Mudik ke Solo',
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
                            ),
                            onSubmitted: (_) => _mulai(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MunculBertahap(
                          indeks: 4,
                          child: Text(
                            'Boleh dikosongkan — nanti dinamai dengan tanggal hari ini.',
                            style: text.bodySmall?.copyWith(
                              color: TourvellaColors.base.withValues(
                                alpha: 0.45,
                              ),
                            ),
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
                                  onTap: () =>
                                      setState(() => _mode = TripMode.solo),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PilihanMode(
                                  ikon: Icons.group_outlined,
                                  judul: 'Bareng',
                                  keterangan: 'Teman bisa gabung',
                                  terpilih: _mode == TripMode.group,
                                  onTap: () =>
                                      setState(() => _mode = TripMode.group),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Alat pengembangan: muncul hanya kalau servernya
                        // mengizinkan, dan hanya untuk Trip Bareng.
                        AnimatedSize(
                          duration: TourvellaMotion.sedang,
                          curve: TourvellaMotion.mengalir,
                          child:
                              _mode == TripMode.group &&
                                  (ref.watch(simulasiTersediaProvider).value ??
                                      false)
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: _SaklarSimulasi(
                                    nyala: _simulasi,
                                    onUbah: (v) =>
                                        setState(() => _simulasi = v),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        const SizedBox(height: 22),
                        MunculBertahap(
                          indeks: 5,
                          child: _PilihTujuan(
                            tujuan: _tujuan,
                            onPilih: (t) => setState(() => _tujuan = t),
                          ),
                        ),
                        const SizedBox(height: 28),
                        MunculBertahap(
                          indeks: 6,
                          child: _PilihModa(
                            terpilih: _moda,
                            onPilih: (m) => setState(() {
                              _moda = m;
                              // Kendaraan garasi yang jenisnya lain tidak
                              // lagi cocok dengan pilihan ini.
                              _kendaraanId = null;
                            }),
                          ),
                        ),
                        MunculBertahap(
                          indeks: 6,
                          child: _PilihKendaraan(
                            terpilih: _kendaraanId,
                            onPilih: (k) => setState(() {
                              _kendaraanId = k?.id;
                              final jenis = ModaPenanda.dari(k?.jenis.wire);
                              if (k != null && jenis != ModaPenanda.lainnya) {
                                _moda = jenis;
                              }
                            }),
                          ),
                        ),
                        MunculBertahap(
                          indeks: 6,
                          child: _PilihSusurUlang(
                            terpilih: _yangDisusuri,
                            onPilih: (t) => setState(() => _yangDisusuri = t),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                    child: MunculBertahap(
                      indeks: 7,
                      child: FilledButton.icon(
                        onPressed: _memulai ? null : _mulai,
                        style: FilledButton.styleFrom(
                          backgroundColor: TourvellaColors.ember,
                          foregroundColor: TourvellaColors.malam,
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        icon: _memulai
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TourvellaColors.malam,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _memulai
                              ? 'Menyiapkan...'
                              : _yangDisusuri == null
                              ? 'Mulai merekam'
                              : 'Mulai susur ulang',
                        ),
                      ),
                    ),
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
        gradasi: const [TourvellaColors.ember, TourvellaColors.emberRedup],
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

    return TourvellaPressable(
      onTap: onTap,
      skala: 0.96,
      child: AnimatedContainer(
        duration: TourvellaMotion.cepat,
        curve: TourvellaMotion.mengalir,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: terpilih
              ? TourvellaColors.ember.withValues(alpha: 0.14)
              : TourvellaColors.malamNaik.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: terpilih ? TourvellaColors.ember : TourvellaColors.kontur,
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
                  ? TourvellaColors.ember
                  : TourvellaColors.base.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              judul,
              style: text.titleMedium?.copyWith(
                color: TourvellaColors.base,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            LabelKapital(
              keterangan,
              warna: TourvellaColors.base.withValues(alpha: 0.5),
              ukuran: 9,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilihan menyusuri ulang perjalanan lama.
///
/// "Susur ulang" adalah menyusuri kembali jejak perjalanan lama. Dulu
/// bernama "napak tilas"; diganti bersama nama lama aplikasinya supaya
/// tidak ada yang terbaca sebagai sisa merek Napak.
class _PilihSusurUlang extends ConsumerWidget {
  const _PilihSusurUlang({required this.terpilih, required this.onPilih});

  final Trip? terpilih;
  final ValueChanged<Trip?> onPilih;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final semua = ref.watch(tripListProvider).value ?? const <Trip>[];

    // Yang bisa disusuri ulang cuma perjalanan yang sudah selesai dan punya
    // cukup jejak untuk dibandingkan.
    final bisa = semua
        .where((t) => !t.isRecording && t.pointCount >= 10)
        .toList();

    if (bisa.isEmpty) return const SizedBox.shrink();

    if (terpilih != null) {
      return TourvellaPressable(
        onTap: () => onPilih(null),
        skala: 0.98,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TourvellaColors.ember.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TourvellaColors.ember, width: 1.6),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 20,
                color: TourvellaColors.ember,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelKapital('Menyusuri ulang', ukuran: 9),
                    const SizedBox(height: 3),
                    Text(
                      terpilih!.title,
                      style: text.titleMedium?.copyWith(
                        color: TourvellaColors.base,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.close_rounded,
                size: 18,
                color: TourvellaColors.base.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      );
    }

    return TourvellaPressable(
      onTap: () => _pilih(context, bisa),
      skala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TourvellaColors.malamNaik.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TourvellaColors.kontur),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 20,
              color: TourvellaColors.emberRedup,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Susuri ulang perjalanan lama',
                    style: text.titleMedium?.copyWith(
                      color: TourvellaColors.base,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ulangi rute yang pernah kamu tempuh, lihat bedanya.',
                    style: text.bodySmall?.copyWith(
                      color: TourvellaColors.base.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: TourvellaColors.emberRedup,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pilih(BuildContext context, List<Trip> bisa) async {
    final hasil = await showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.9,
        builder: (sheetContext, gulir) => ListView.builder(
          controller: gulir,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          itemCount: bisa.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mau menyusuri ulang yang mana?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tourvella akan menunjukkan rute lamamu di peta dan '
                      'membandingkan perjalanan hari ini dengan hari itu.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            final t = bisa[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TourvellaPressable(
                onTap: () => Navigator.of(sheetContext).pop(t),
                skala: 0.98,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TourvellaColors.malamNaik.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TourvellaColors.kontur),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${t.distanceKm.toStringAsFixed(1)} km'
                              '${t.startedAt == null ? '' : ' · ${DateFormat("d MMM yyyy", 'id_ID').format(t.startedAt!)}'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: TourvellaColors.emberRedup,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (hasil != null) onPilih(hasil);
  }
}

/// Kendaraan yang menemani perjalanan kali ini, dari garasi.
///
/// Tidak tampil sama sekali kalau garasinya kosong — layar ini sudah cukup
/// berisi, dan orang yang belum punya garasi tidak perlu diingatkan.
/// Pilih tujuan yang mau dipandu dengan suara.
///
/// Opsional, dan tetap opsional: Tourvella merekam cerita perjalanan, dan
/// banyak perjalanan memang tidak punya tujuan yang diketik dulu.
class _PilihTujuan extends StatelessWidget {
  const _PilihTujuan({required this.tujuan, required this.onPilih});

  final Tujuan? tujuan;
  final ValueChanged<Tujuan?> onPilih;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ada = tujuan != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LabelKapital('Dipandu ke'),
        const SizedBox(height: 10),
        TourvellaPressable(
          skala: 0.98,
          onTap: () async {
            final pilihan = await PilihTujuanSheet.tampilkan(context);
            if (pilihan != null) onPilih(pilihan);
          },
          child: AnimatedContainer(
            duration: TourvellaMotion.cepat,
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: TourvellaColors.malamNaik.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ada ? TourvellaColors.ember : TourvellaColors.kontur,
                width: ada ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ada ? Icons.navigation_rounded : Icons.explore_outlined,
                  size: 20,
                  color: ada
                      ? TourvellaColors.ember
                      : TourvellaColors.base.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ada ? tujuan!.nama : 'Belum ditentukan',
                        style: text.titleSmall?.copyWith(
                          color: TourvellaColors.base,
                        ),
                      ),
                      Text(
                        ada
                            ? 'Tourvella memandu dengan suara sepanjang jalan.'
                            : 'Opsional — ketuk kalau mau dipandu suara.',
                        style: text.bodySmall?.copyWith(
                          color: TourvellaColors.base.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ada)
                  IconButton(
                    tooltip: 'Batalkan tujuan',
                    onPressed: () => onPilih(null),
                    icon: Icon(
                      Icons.close_rounded,
                      color: TourvellaColors.base.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Saklar rombongan simulasi di layar berangkat.
///
/// Ditulis apa adanya sebagai alat pengembangan. Lima rekan palsu jauh lebih
/// berguna daripada lima HP sungguhan saat sedang membangun konvoi, tapi
/// tidak boleh sedetik pun terbaca sebagai teman betulan.
class _SaklarSimulasi extends StatelessWidget {
  const _SaklarSimulasi({required this.nyala, required this.onUbah});

  final bool nyala;
  final ValueChanged<bool> onUbah;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: TourvellaColors.malamNaik.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: nyala ? TourvellaColors.ember : TourvellaColors.kontur,
          width: nyala ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 20,
            color: nyala
                ? TourvellaColors.ember
                : TourvellaColors.base.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rombongan simulasi',
                  style: text.titleSmall?.copyWith(
                    color: TourvellaColors.base,
                  ),
                ),
                Text(
                  'Lima rekan palsu berjarak 50 m, untuk mencoba sendirian.',
                  style: text.bodySmall?.copyWith(
                    color: TourvellaColors.base.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: nyala, onChanged: onUbah),
        ],
      ),
    );
  }
}

/// Motor, matic, mobil, atau sepeda — selalu tampil, garasi kosong pun.
///
/// Fotonya kendaraan sungguhan, supaya pilihan ini terasa seperti memilih
/// tunggangan, bukan mengisi formulir.
class _PilihModa extends StatelessWidget {
  const _PilihModa({required this.terpilih, required this.onPilih});

  final ModaPenanda terpilih;
  final ValueChanged<ModaPenanda> onPilih;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelKapital('Berangkat naik'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, m) in ModaPenanda.pilihan.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _KartuModa(
                    moda: m,
                    pilih: m == terpilih,
                    onTap: () => onPilih(m),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KartuModa extends StatelessWidget {
  const _KartuModa({
    required this.moda,
    required this.pilih,
    required this.onTap,
  });

  final ModaPenanda moda;
  final bool pilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: pilih,
      label: moda.label,
      child: TourvellaPressable(
        skala: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TourvellaMotion.cepat,
          curve: TourvellaMotion.mengalir,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          decoration: BoxDecoration(
            color: pilih
                ? TourvellaColors.ember.withValues(alpha: 0.16)
                : TourvellaColors.malamNaik.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pilih ? TourvellaColors.ember : TourvellaColors.kontur,
              width: pilih ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: pilih ? 1.08 : 0.94,
                duration: TourvellaMotion.sedang,
                curve: TourvellaMotion.memantul,
                child: Image.asset(
                  moda.aset!,
                  height: 54,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                moda.label,
                style: TextStyle(
                  color: pilih
                      ? TourvellaColors.base
                      : TourvellaColors.base.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: pilih ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilihKendaraan extends ConsumerWidget {
  const _PilihKendaraan({required this.terpilih, required this.onPilih});

  final String? terpilih;
  final ValueChanged<Kendaraan?> onPilih;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garasi = ref.watch(garasiProvider('saya')).value ?? const [];
    if (garasi.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelKapital('Dari garasimu'),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: garasi.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final k = garasi[i];
                final pilih = k.id == terpilih;
                return TourvellaPressable(
                  skala: 0.94,
                  onTap: () => onPilih(pilih ? null : k),
                  child: AnimatedContainer(
                    duration: TourvellaMotion.cepat,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: pilih
                          ? TourvellaColors.ember.withValues(alpha: 0.16)
                          : TourvellaColors.malamNaik.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pilih
                            ? TourvellaColors.ember
                            : TourvellaColors.kontur,
                        width: pilih ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          k.jenis.ikon,
                          size: 18,
                          color: pilih
                              ? TourvellaColors.ember
                              : TourvellaColors.base.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          k.nama,
                          style: TextStyle(
                            color: TourvellaColors.base,
                            fontWeight: pilih
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
