import 'package:flutter/material.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_skeleton.dart';

/// Lingkaran berisi inisial, untuk yang belum memasang foto profil.
///
/// Foto profil sendiri ada di `FotoProfil`, yang jatuh ke lingkaran ini saat
/// fotonya belum ada atau gagal dimuat.
///
/// Warnanya diambil dari nama, jadi orang yang sama selalu berwarna sama di
/// mana pun dia muncul — di daftar teman, di obrolan, di inbox.
class LingkaranNama extends StatelessWidget {
  const LingkaranNama({
    required this.nama,
    this.ukuran = 44,
    this.cincin = false,
    super.key,
  });

  final String nama;
  final double ukuran;

  /// Cincin tipis untuk yang sedang aktif, mis. sedang mengetik.
  final bool cincin;

  // Semuanya dari palet. Warna keempat adalah `affirm` yang dipudarkan,
  // bukan hijau baru — menambah warna di luar palet demi variasi avatar
  // adalah cara paling cepat membuat aplikasinya terasa norak.
  static final _pasangan = [
    (TourvellaColors.softSky, TourvellaColors.deepAccent),
    (TourvellaColors.warmNeutral, TourvellaColors.textPrimary),
    (TourvellaColors.primary, TourvellaColors.textPrimary),
    (
      TourvellaColors.affirm.withValues(alpha: 0.35),
      TourvellaColors.textPrimary,
    ),
  ];

  String get _inisial {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian.first[0] + bagian.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (latar, tulisan) =
        _pasangan[nama.codeUnits.fold<int>(0, (a, b) => a + b) %
            _pasangan.length];

    return AnimatedContainer(
      duration: TourvellaMotion.cepat,
      width: ukuran,
      height: ukuran,
      padding: EdgeInsets.all(cincin ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cincin ? TourvellaColors.deepAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
        child: Center(
          child: Text(
            _inisial,
            style: TextStyle(
              color: tulisan,
              fontWeight: FontWeight.w700,
              fontSize: ukuran * 0.36,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana angka kecil, mis. pesan belum dibaca.
///
/// Muncul dengan memantul dan hilang dengan mengecil — angka yang tiba-tiba
/// ada atau tiba-tiba hilang terlihat seperti kedipan layar.
class LencanaAngka extends StatelessWidget {
  const LencanaAngka({required this.angka, super.key});

  final int angka;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: TourvellaMotion.cepat,
      switchInCurve: TourvellaMotion.memantul,
      transitionBuilder: (anak, animasi) =>
          ScaleTransition(scale: animasi, child: anak),
      child: angka <= 0
          ? const SizedBox.shrink(key: ValueKey(0))
          : Container(
              key: ValueKey(angka),
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: TourvellaColors.deepAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                angka > 99 ? '99+' : '$angka',
                style: const TextStyle(
                  color: TourvellaColors.textOnDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

/// Ikon dengan titik lencana di pojoknya, untuk tombol di bilah atas.
class IkonBerlencana extends StatelessWidget {
  const IkonBerlencana({
    required this.ikon,
    required this.jumlah,
    required this.onTap,
    required this.label,
    this.warna,
    super.key,
  });

  final IconData ikon;
  final int jumlah;
  final VoidCallback onTap;
  final String label;

  /// Warna ikonnya. Di atas panorama malam beranda, ikon gelap hilang.
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(ikon, color: warna ?? TourvellaColors.textPrimary),
          Positioned(
            right: -8,
            top: -6,
            child: Transform.scale(
              scale: 0.85,
              child: LencanaAngka(angka: jumlah),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keadaan kosong yang hangat, bukan "Tidak ada data".
class KosongHangat extends StatelessWidget {
  const KosongHangat({
    required this.ikon,
    required this.judul,
    required this.isi,
    this.aksi,
    super.key,
  });

  final IconData ikon;
  final String judul;
  final String isi;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: TourvellaMotion.lambat,
          curve: TourvellaMotion.mengalir,
          builder: (context, t, anak) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 16),
              child: anak,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: TourvellaColors.softSky,
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, size: 34, color: TourvellaColors.deepAccent),
              ),
              const SizedBox(height: 20),
              Text(judul, style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                isi,
                style: text.bodyMedium?.copyWith(
                  color: TourvellaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (aksi != null) ...[const SizedBox(height: 22), aksi!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kerangka daftar orang, selama isinya dimuat.
class KerangkaDaftarOrang extends StatelessWidget {
  const KerangkaDaftarOrang({this.jumlah = 5, super.key});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jumlah,
      separatorBuilder: (context, i) => const SizedBox(height: 18),
      itemBuilder: (context, i) => const Row(
        children: [
          TourvellaSkeleton(tinggi: 44, lebar: 44, radius: 22),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TourvellaSkeleton.teks(lebar: 140),
                SizedBox(height: 8),
                TourvellaSkeleton.teks(lebar: 220),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "5 mnt", "kemarin", "12 Sep" — cara orang menyebut waktu, bukan stempel.
String waktuSantai(DateTime waktu, {DateTime? sekarang}) {
  final kini = sekarang ?? DateTime.now();
  final selisih = kini.difference(waktu);

  if (selisih.inSeconds < 60) return 'baru saja';
  if (selisih.inMinutes < 60) return '${selisih.inMinutes} mnt';
  if (selisih.inHours < 24 && kini.day == waktu.day) {
    return '${selisih.inHours} jam';
  }

  final kemarin = DateTime(kini.year, kini.month, kini.day - 1);
  if (waktu.year == kemarin.year &&
      waktu.month == kemarin.month &&
      waktu.day == kemarin.day) {
    return 'kemarin';
  }

  const bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final teks = '${waktu.day} ${bulan[waktu.month - 1]}';
  return waktu.year == kini.year ? teks : '$teks ${waktu.year}';
}
