import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_gerak.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../groups/application/live_location_controller.dart';
import '../../groups/data/live_location_service.dart';
import '../application/intercom_controller.dart';
import '../data/intercom_service.dart';

/// Telepon rombongan — ngobrol sambil jalan, seperti telepon grup.
///
/// Suara, bukan teks (obrolan teks tempatnya di Obrolan). Tiga keadaan:
///
/// 1. Belum ada yang menelepon → ajakan "Mulai telepon".
/// 2. Teman sedang menelepon → kartu yang menyala: "Gilang menelepon
///    rombongan — Gabung". HP bergetar sekali saat itu terjadi.
/// 3. Kamu di dalam → bilah panggilan dengan durasi, bisu, dan tutup; ketuk
///    untuk layar penuh.
///
/// Tidak pernah tersambung otomatis: mikrofon baru menyala setelah kamu
/// sendiri mengetuk.
class PanelTelepon extends ConsumerWidget {
  const PanelTelepon({required this.tripId, this.judul, super.key});

  final String tripId;
  final String? judul;

  Future<void> _masuk(BuildContext context, WidgetRef ref) async {
    final aksi = ref.read(intercomControllerProvider.notifier);
    if (ref.read(intercomControllerProvider).aktif) await aksi.keluar();
    await aksi.gabung(tripId);
    if (!context.mounted || !ref.read(intercomControllerProvider).aktif) return;
    await LayarTelepon.buka(context, tripId: tripId, judul: judul);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intercom = ref.watch(intercomControllerProvider);
    final telepon = ref.watch(
      liveLocationControllerProvider(tripId).select((s) => s.telepon),
    );
    final diDalam = intercom.tripId == tripId;

    // Teman baru saja memulai telepon: getar sekali, seperti panggilan masuk.
    ref.listen(
      liveLocationControllerProvider(tripId).select((s) => s.telepon.aktif),
      (sebelum, sekarang) {
        if (sebelum == false && sekarang && !diDalam) {
          HapticFeedback.heavyImpact();
        }
      },
    );

    ref.listen(intercomControllerProvider.select((s) => s.pesan), (_, pesan) {
      if (pesan == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      ref.read(intercomControllerProvider.notifier).hapusPesan();
    });

    return AnimatedSwitcher(
      duration: TourvellaMotion.sedang,
      switchInCurve: TourvellaMotion.mengalir,
      child: diDalam
          ? _BilahPanggilan(
              key: const ValueKey('di-dalam'),
              intercom: intercom,
              onBuka: () =>
                  LayarTelepon.buka(context, tripId: tripId, judul: judul),
            )
          : telepon.aktif
          ? _PanggilanMasuk(
              key: const ValueKey('masuk'),
              telepon: telepon,
              onGabung: () => _masuk(context, ref),
            )
          : _AjakanTelepon(
              key: const ValueKey('ajakan'),
              onMulai: () => _masuk(context, ref),
            ),
    );
  }
}

BoxDecoration _kartu({Color? garis}) => BoxDecoration(
  color: TourvellaColors.base.withValues(alpha: 0.96),
  borderRadius: BorderRadius.circular(20),
  border: garis == null ? null : Border.all(color: garis, width: 2),
  boxShadow: [
    BoxShadow(
      color: TourvellaColors.textPrimary.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

class _AjakanTelepon extends StatelessWidget {
  const _AjakanTelepon({required this.onMulai, super.key});

  final VoidCallback onMulai;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: _kartu(),
      child: Row(
        children: [
          const _IkonBulat(
            ikon: Icons.call_rounded,
            latar: TourvellaColors.softSky,
            warna: TourvellaColors.deepAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telepon rombongan',
                  style: text.titleSmall?.copyWith(
                    color: TourvellaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ngobrol sambil jalan, seperti telepon grup. Tidak direkam.',
                  style: text.bodySmall?.copyWith(
                    color: TourvellaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onMulai,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Mulai'),
          ),
        ],
      ),
    );
  }
}

class _PanggilanMasuk extends StatelessWidget {
  const _PanggilanMasuk({
    required this.telepon,
    required this.onGabung,
    super.key,
  });

  final StatusTelepon telepon;
  final VoidCallback onGabung;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final siapa = telepon.nama.isEmpty ? 'Rombongan' : telepon.nama.first;
    final lain = telepon.jumlah - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: _kartu(garis: TourvellaColors.affirm),
      child: Row(
        children: [
          const _IkonBulat(
            ikon: Icons.phone_in_talk_rounded,
            latar: TourvellaColors.affirm,
            warna: TourvellaColors.base,
            berdenyut: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$siapa menelepon rombongan',
                  style: text.titleSmall?.copyWith(
                    color: TourvellaColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lain > 0
                      ? 'Bersama $lain orang lain. Ketuk gabung untuk ikut.'
                      : 'Ketuk gabung untuk ikut ngobrol.',
                  style: text.bodySmall?.copyWith(
                    color: TourvellaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: TourvellaColors.affirm,
              foregroundColor: TourvellaColors.textPrimary,
            ),
            onPressed: onGabung,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Gabung'),
          ),
        ],
      ),
    );
  }
}

/// Saat kamu di dalam telepon: durasi, siapa yang bicara, bisu, tutup.
class _BilahPanggilan extends ConsumerWidget {
  const _BilahPanggilan({
    required this.intercom,
    required this.onBuka,
    super.key,
  });

  final IntercomState intercom;
  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aksi = ref.read(intercomControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final yangBicara = intercom.anggota
        .where((a) => intercom.bicara.contains(a.userId))
        .map((a) => a.nama)
        .toList();

    return TourvellaPressable(
      skala: 0.98,
      onTap: onBuka,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: TourvellaColors.malam,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: TourvellaColors.textPrimary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            TitikBerdenyut(
              warna: intercom.tersambung
                  ? TourvellaColors.affirm
                  : TourvellaColors.textSecondary,
              ukuran: 8,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Telepon rombongan',
                        style: text.labelLarge?.copyWith(
                          color: TourvellaColors.base,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Durasi(
                        sejak: intercom.mulaiPada,
                        gaya: text.labelLarge?.copyWith(
                          color: TourvellaColors.emberRedup,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _keterangan(intercom, yangBicara),
                    style: text.bodySmall?.copyWith(
                      color: TourvellaColors.base.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _TombolPanggilan(
              ikon: intercom.bisu ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: intercom.bisu ? 'Nyalakan mikrofon' : 'Bisukan mikrofon',
              latar: intercom.bisu
                  ? TourvellaColors.base
                  : TourvellaColors.kontur,
              warna: intercom.bisu
                  ? TourvellaColors.malam
                  : TourvellaColors.base,
              cincin: intercom.sayaBicara ? TourvellaColors.affirm : null,
              ukuran: 46,
              onTap: () => aksi.aturBisu(!intercom.bisu),
            ),
            const SizedBox(width: 8),
            _TombolPanggilan(
              ikon: Icons.call_end_rounded,
              label: 'Tutup telepon',
              latar: TourvellaColors.attention,
              warna: TourvellaColors.base,
              ukuran: 46,
              onTap: aksi.keluar,
            ),
          ],
        ),
      ),
    );
  }
}

String _keterangan(IntercomState i, List<String> yangBicara) {
  if (i.menyambung) return 'Menyambungkan…';
  if (!i.tersambung) return 'Sinyal putus, menyambung lagi…';
  if (yangBicara.isNotEmpty) return '${yangBicara.join(', ')} sedang bicara';
  if (i.bisu) return 'Mikrofonmu bisu — suaramu tidak dikirim';
  if (i.anggota.length <= 1) return 'Menunggu teman bergabung…';
  return '${i.anggota.length} orang di telepon';
}

/// Layar penuh saat menelepon, seperti telepon grup biasa.
///
/// Ditutup ("kecilkan") tidak memutus telepon — peta tetap bisa dilihat
/// sementara obrolan jalan terus. Yang memutus hanya tombol merah.
class LayarTelepon extends ConsumerWidget {
  const LayarTelepon({required this.tripId, this.judul, super.key});

  final String tripId;
  final String? judul;

  static Future<void> buka(
    BuildContext context, {
    required String tripId,
    String? judul,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: TourvellaMotion.sedang,
        reverseTransitionDuration: TourvellaMotion.cepat,
        pageBuilder: (_, _, _) => LayarTelepon(tripId: tripId, judul: judul),
        transitionsBuilder: (_, a, _, anak) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: a, curve: TourvellaMotion.mengalir),
          ),
          child: anak,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intercom = ref.watch(intercomControllerProvider);
    final aksi = ref.read(intercomControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    // Telepon ditutup (di sini atau karena perjalanan ditutup): layar ikut
    // pergi.
    ref.listen(intercomControllerProvider.select((s) => s.aktif), (_, aktif) {
      if (!aktif && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });

    return Scaffold(
      backgroundColor: TourvellaColors.malam,
      body: LatarEkspedisi(
        gunung: true,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Kecilkan — telepon tetap jalan',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: TourvellaColors.base,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Telepon rombongan',
                style: text.titleLarge?.copyWith(color: TourvellaColors.base),
              ),
              if (judul != null) ...[
                const SizedBox(height: 4),
                Text(
                  judul!,
                  style: text.bodyMedium?.copyWith(
                    color: TourvellaColors.base.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _Durasi(
                sejak: intercom.mulaiPada,
                gaya: text.titleMedium?.copyWith(
                  color: TourvellaColors.emberRedup,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _keterangan(intercom, [
                  for (final a in intercom.anggota)
                    if (intercom.bicara.contains(a.userId)) a.nama,
                ]),
                style: text.bodySmall?.copyWith(
                  color: TourvellaColors.base.withValues(alpha: 0.6),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 22,
                      runSpacing: 22,
                      children: [
                        for (final a in intercom.anggota)
                          _Peserta(
                            anggota: a,
                            bicara: intercom.bicara.contains(a.userId),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TombolBerlabel(
                      label: intercom.bisu ? 'Bisu' : 'Mikrofon',
                      child: _TombolPanggilan(
                        ikon: intercom.bisu
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: intercom.bisu
                            ? 'Nyalakan mikrofon'
                            : 'Bisukan mikrofon',
                        latar: intercom.bisu
                            ? TourvellaColors.base
                            : TourvellaColors.kontur,
                        warna: intercom.bisu
                            ? TourvellaColors.malam
                            : TourvellaColors.base,
                        cincin: intercom.sayaBicara
                            ? TourvellaColors.affirm
                            : null,
                        ukuran: 72,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          aksi.aturBisu(!intercom.bisu);
                        },
                      ),
                    ),
                    _TombolBerlabel(
                      label: 'Tutup',
                      child: _TombolPanggilan(
                        ikon: Icons.call_end_rounded,
                        label: 'Tutup telepon',
                        latar: TourvellaColors.attention,
                        warna: TourvellaColors.base,
                        ukuran: 72,
                        onTap: aksi.keluar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Peserta extends StatelessWidget {
  const _Peserta({required this.anggota, required this.bicara});

  final AnggotaSuara anggota;
  final bool bicara;

  @override
  Widget build(BuildContext context) {
    final nama = anggota.nama.trim();
    final huruf = nama.isEmpty ? '?' : nama[0].toUpperCase();

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cincin yang menyala saat orangnya bicara — dari jauh pun
              // kelihatan siapa yang sedang ngomong.
              AnimatedContainer(
                duration: TourvellaMotion.cepat,
                curve: TourvellaMotion.mengalir,
                height: 84,
                width: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TourvellaColors.malamNaik,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: bicara
                        ? TourvellaColors.affirm
                        : TourvellaColors.kontur,
                    width: bicara ? 4 : 1.5,
                  ),
                  boxShadow: bicara
                      ? [
                          BoxShadow(
                            color: TourvellaColors.affirm.withValues(
                              alpha: 0.45,
                            ),
                            blurRadius: 18,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  huruf,
                  style: const TextStyle(
                    color: TourvellaColors.base,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (anggota.bisu)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: TourvellaColors.base,
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 16,
                      color: TourvellaColors.attention,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nama,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TourvellaColors.base),
          ),
        ],
      ),
    );
  }
}

class _TombolBerlabel extends StatelessWidget {
  const _TombolBerlabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: TourvellaColors.base.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _TombolPanggilan extends StatelessWidget {
  const _TombolPanggilan({
    required this.ikon,
    required this.label,
    required this.latar,
    required this.warna,
    required this.ukuran,
    required this.onTap,
    this.cincin,
  });

  final IconData ikon;
  final String label;
  final Color latar;
  final Color warna;
  final double ukuran;
  final Color? cincin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TourvellaPressable(
        skala: 0.9,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TourvellaMotion.cepat,
          curve: TourvellaMotion.mengalir,
          height: ukuran,
          width: ukuran,
          decoration: BoxDecoration(
            color: latar,
            shape: BoxShape.circle,
            border: Border.all(
              color: cincin ?? Colors.transparent,
              width: 3,
            ),
          ),
          child: Icon(ikon, color: warna, size: ukuran * 0.45),
        ),
      ),
    );
  }
}

class _IkonBulat extends StatelessWidget {
  const _IkonBulat({
    required this.ikon,
    required this.latar,
    required this.warna,
    this.berdenyut = false,
  });

  final IconData ikon;
  final Color latar;
  final Color warna;
  final bool berdenyut;

  @override
  Widget build(BuildContext context) {
    final bulat = Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
      child: Icon(ikon, color: warna),
    );
    if (!berdenyut) return bulat;
    return Stack(
      alignment: Alignment.center,
      children: [
        TitikBerdenyut(warna: latar, ukuran: 44),
        bulat,
      ],
    );
  }
}

/// "03:12" sejak masuk telepon, berdetak tiap detik.
class _Durasi extends StatefulWidget {
  const _Durasi({required this.sejak, this.gaya});

  final DateTime? sejak;
  final TextStyle? gaya;

  @override
  State<_Durasi> createState() => _DurasiState();
}

class _DurasiState extends State<_Durasi> {
  Timer? _detak;

  @override
  void initState() {
    super.initState();
    _detak = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sejak = widget.sejak;
    if (sejak == null) return const SizedBox.shrink();
    final d = DateTime.now().difference(sejak);
    final jam = d.inHours;
    final menit = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final detik = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      jam > 0 ? '$jam:$menit:$detik' : '$menit:$detik',
      style: widget.gaya,
    );
  }
}

