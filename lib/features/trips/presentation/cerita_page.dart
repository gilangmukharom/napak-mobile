import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../render/presentation/video_sheet.dart';
import '../data/trip_models.dart';
import 'pratinjau_rute.dart';

final _ceritaProvider = FutureProvider.autoDispose
    .family<({Trip trip, List<TripPoint> titik}), String>((ref, tripId) async {
      final repo = ref.watch(tripRepositoryProvider);
      final (trip, titik) = await (repo.detail(tripId), repo.points(tripId)).wait;
      return (trip: trip, titik: titik);
    });

/// Cerita Perjalanan.
///
/// Meminjam mekanika story yang sudah hafal di jari orang — layar penuh,
/// ketuk kanan untuk lanjut, bilah ruas di atas — tapi **kebalikan
/// semantiknya**.
///
/// Story menghilang dalam 24 jam. Napak berdiri di atas satu kalimat: "jejak
/// itu tidak hilang begitu saja." Membangun fitur yang sifat utamanya
/// menghilang berarti melawan alasan produk ini ada. Jadi yang diambil cuma
/// caranya bercerita; isinya tetap tersimpan selamanya dan bisa dibuka lagi
/// kapan pun.
///
/// Fotonya memenuhi layar, bukan duduk di dalam kartu. Foto yang dibingkai
/// terbaca sebagai lampiran pada tulisan; foto yang memenuhi layar terbaca
/// sebagai tempat — dan tempat itulah yang sedang diceritakan.
class CeritaPage extends ConsumerStatefulWidget {
  const CeritaPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<CeritaPage> createState() => _CeritaPageState();
}

class _CeritaPageState extends ConsumerState<CeritaPage> {
  /// Lama tiap ruas sebelum berpindah sendiri.
  ///
  /// Lebih lama daripada story biasa. Yang dilihat di sini kenangan sendiri,
  /// bukan unggahan orang lain yang dilewati sambil lalu — dan Napak memang
  /// bukan aplikasi yang buru-buru.
  static const _durasiRuas = Duration(seconds: 6);

  int _indeks = 0;
  Timer? _jalan;
  bool _ditahan = false;
  double _progres = 0;

  @override
  void dispose() {
    _jalan?.cancel();
    super.dispose();
  }

  void _mulaiRuas(int jumlahRuas) {
    _jalan?.cancel();
    _progres = 0;

    const detak = Duration(milliseconds: 50);
    _jalan = Timer.periodic(detak, (_) {
      if (!mounted || _ditahan) return;

      setState(() {
        _progres += detak.inMilliseconds / _durasiRuas.inMilliseconds;
        if (_progres >= 1) {
          _progres = 0;
          if (_indeks < jumlahRuas - 1) {
            _indeks++;
          } else {
            // Ruas terakhir berhenti sendiri, tidak mengulang. Ceritanya
            // punya akhir — itu bedanya dengan umpan yang tidak habis-habis.
            _jalan?.cancel();
            _progres = 1;
          }
        }
      });
    });
  }

  void _ke(int tujuan, int jumlahRuas) {
    if (tujuan < 0) return;
    if (tujuan >= jumlahRuas) {
      context.pop();
      return;
    }
    setState(() => _indeks = tujuan);
    _mulaiRuas(jumlahRuas);
  }

  @override
  Widget build(BuildContext context) {
    final cerita = ref.watch(_ceritaProvider(widget.tripId));

    return Scaffold(
      // Kanvasnya gelap, bukan base. Latar terang akan berkedip putih tiap
      // kali foto berganti — dan di layar penuh kedipan itu terbaca seperti
      // aplikasinya tersendat.
      backgroundColor: NapakColors.textPrimary,
      body: cerita.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NapakColors.primary),
        ),
        error: (error, _) => _Galat(pesan: error.toString()),
        data: (data) {
          final ruas = _susunRuas(data.trip, data.titik);
          _jalan ??= () {
            // Dimulai sekali, setelah isinya benar-benar ada.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _mulaiRuas(ruas.length),
            );
            return null;
          }();

          final sekarang = ruas[_indeks.clamp(0, ruas.length - 1)];

          return GestureDetector(
            // Tahan untuk membaca lebih lama — catatan panjang kadang perlu
            // lebih dari enam detik.
            onLongPressStart: (_) => setState(() => _ditahan = true),
            onLongPressEnd: (_) => setState(() => _ditahan = false),
            onTapUp: (rincian) {
              final lebar = MediaQuery.of(context).size.width;
              _ke(
                rincian.localPosition.dx < lebar * 0.32
                    ? _indeks - 1
                    : _indeks + 1,
                ruas.length,
              );
            },
            // Geser ke bawah untuk menutup, sama seperti yang sudah hafal.
            onVerticalDragEnd: (rincian) {
              if ((rincian.primaryVelocity ?? 0) > 260) context.pop();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: NapakMotion.sedang,
                    // Menyilang, bukan bergantian. Foto lama tetap terlihat
                    // sampai yang baru penuh, jadi tidak ada jeda hitam di
                    // antara dua ruas.
                    layoutBuilder: (kini, sebelumnya) => Stack(
                      fit: StackFit.expand,
                      children: [...sebelumnya, ?kini],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_indeks),
                      child: sekarang,
                    ),
                  ),
                ),

                // Bayangan tipis di puncak layar supaya bilah ruas tetap
                // terbaca di atas foto yang kebetulan terang.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 170,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x73000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      children: [
                        _BilahRuas(
                          jumlah: ruas.length,
                          indeks: _indeks,
                          progres: _progres,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Tanda jeda muncul saat ditahan, supaya jelas
                            // ceritanya berhenti karena disuruh, bukan macet.
                            AnimatedOpacity(
                              opacity: _ditahan ? 1 : 0,
                              duration: NapakMotion.kilat,
                              child: const Row(
                                children: [
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.pause_rounded,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'dijeda',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: NapakColors.textOnDeep,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Menyusun perjalanan jadi ruas-ruas cerita.
  ///
  /// Pembuka dengan bentuk rutenya, satu ruas untuk tiap singgahan, lalu
  /// penutup berisi angka. Titik yang tidak ditandai apa-apa tidak jadi ruas
  /// — enam ratus koordinat bukan cerita.
  List<Widget> _susunRuas(Trip trip, List<TripPoint> titik) {
    final singgahan = titik
        .where((t) => t.note != null || t.photoUrl != null)
        .toList();

    // Pembuka dan penutup meminjam foto dari singgahan pertama dan terakhir.
    // Perjalanan tanpa foto sama sekali tetap dapat latar bergradasi, jadi
    // bentuk halamannya tidak berubah-ubah tergantung isi.
    final berfoto = singgahan
        .where((t) => t.photoUrl != null)
        .map((t) => t.photoUrl!)
        .toList();

    return [
      _RuasPembuka(
        trip: trip,
        titik: titik,
        foto: berfoto.isEmpty ? null : berfoto.first,
      ),
      for (var i = 0; i < singgahan.length; i++)
        _RuasSinggahan(titik: singgahan[i], urutan: i),
      _RuasPenutup(
        trip: trip,
        jumlahSinggahan: singgahan.length,
        foto: berfoto.isEmpty ? null : berfoto.last,
      ),
    ];
  }
}

/// Latar satu ruas: fotonya memenuhi layar, perlahan bergerak.
///
/// Gerakan lambatnya bukan hiasan. Foto diam di layar penuh terbaca seperti
/// aplikasinya membeku; bergeser sedikit demi sedikit membuat layarnya terasa
/// hidup tanpa menarik perhatian dari isinya.
class _LatarFoto extends StatelessWidget {
  const _LatarFoto({
    required this.foto,
    required this.benih,
    required this.anak,
  });

  final String? foto;

  /// Menentukan arah geseran, supaya dua ruas berturut-turut tidak bergerak
  /// ke arah yang persis sama.
  final int benih;

  final Widget anak;

  @override
  Widget build(BuildContext context) {
    final arah = _arahGeser(benih);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dasar bergradasi. Dipasang selalu, bukan cuma saat fotonya tidak
        // ada — ini yang terlihat selama fotonya masih diunduh.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [NapakColors.deepAccent, NapakColors.textPrimary],
            ),
          ),
        ),

        if (foto != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            // Lebih lama daripada satu ruas, jadi geserannya tidak pernah
            // sampai berhenti di depan mata.
            duration: const Duration(milliseconds: 8000),
            curve: Curves.linear,
            builder: (context, t, anakFoto) => Transform.scale(
              scale: 1.06 + t * 0.1,
              alignment: arah,
              child: anakFoto,
            ),
            child: Image.network(
              foto!,
              fit: BoxFit.cover,
              // Foto muncul dengan memudar, tidak menyentak begitu selesai
              // diunduh.
              frameBuilder: (context, anakGambar, frame, sinkron) {
                if (sinkron) return anakGambar;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: NapakMotion.sedang,
                  curve: NapakMotion.mengalir,
                  child: anakGambar,
                );
              },
              errorBuilder: (context, galat, jejak) => const SizedBox.shrink(),
            ),
          ),

        // Kerudung gelap dari bawah. Tanpa ini tulisan putih hilang begitu
        // fotonya kebetulan terang — dan foto langit siang hampir selalu
        // terang.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x14000000),
                Color(0x00000000),
                Color(0x8A000000),
                Color(0xD6000000),
              ],
              stops: [0, 0.34, 0.72, 1],
            ),
          ),
        ),

        anak,
      ],
    );
  }

  static Alignment _arahGeser(int benih) {
    const arah = [
      Alignment.bottomLeft,
      Alignment.topRight,
      Alignment.bottomRight,
      Alignment.topLeft,
    ];
    return arah[benih % arah.length];
  }
}

/// Bilah ruas di atas — sebanyak ruasnya, yang sudah lewat terisi penuh.
class _BilahRuas extends StatelessWidget {
  const _BilahRuas({
    required this.jumlah,
    required this.indeks,
    required this.progres,
  });

  final int jumlah;
  final int indeks;
  final double progres;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < jumlah; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: i < indeks ? 1 : (i == indeks ? progres : 0),
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(
                    NapakColors.textOnDeep,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RuasPembuka extends StatelessWidget {
  const _RuasPembuka({required this.trip, required this.titik, this.foto});

  final Trip trip;
  final List<TripPoint> titik;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _LatarFoto(
      foto: foto,
      benih: 0,
      anak: Padding(
        padding: const EdgeInsets.fromLTRB(28, 110, 28, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MunculBertahap(
              indeks: 0,
              child: Text(
                trip.startedAt == null
                    ? ''
                    : DateFormat(
                        "EEEE, d MMMM yyyy",
                        'id_ID',
                      ).format(trip.startedAt!),
                style: text.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            MunculBertahap(
              indeks: 1,
              child: Text(
                trip.title,
                style: text.displaySmall?.copyWith(
                  color: NapakColors.textOnDeep,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Bentuk rutenya duduk di atas foto sebagai kartu buram.
            // Pratinjaunya digambar untuk latar terang; menaruhnya langsung
            // di atas foto akan membuat garisnya hilang.
            MunculBertahap(
              indeks: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white.withValues(alpha: 0.22),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: PratinjauRute(
                        titik: [
                          for (final t in titik) (lat: t.lat, lng: t.lng),
                        ],
                        tinggi: 260,
                      ),
                    ),
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

/// Satu singgahan: fotonya jadi seluruh layar, catatannya duduk di atasnya.
class _RuasSinggahan extends StatelessWidget {
  const _RuasSinggahan({required this.titik, required this.urutan});

  final TripPoint titik;
  final int urutan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _LatarFoto(
      foto: titik.photoUrl,
      benih: urutan + 1,
      anak: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 96, 26, 44),
          child: Column(
            // Tulisannya turun ke bawah, menempel pada bagian tergelap
            // kerudung. Bagian tengah dibiarkan kosong supaya fotonya
            // benar-benar terlihat, bukan cuma jadi tempelan di belakang teks.
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MunculBertahap(
                indeks: 0,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        titik.transportMode.label,
                        style: text.labelMedium?.copyWith(
                          color: NapakColors.textOnDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('HH:mm').format(titik.recordedAt),
                      style: text.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (titik.note != null) ...[
                const SizedBox(height: 14),
                MunculBertahap(
                  indeks: 1,
                  child: Text(
                    titik.note!,
                    style: text.headlineSmall?.copyWith(
                      height: 1.35,
                      color: NapakColors.textOnDeep,
                      // Bayangan tipis, untuk foto yang kebetulan terang
                      // justru di bagian bawahnya.
                      shadows: const [
                        Shadow(blurRadius: 18, color: Color(0x99000000)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RuasPenutup extends StatelessWidget {
  const _RuasPenutup({
    required this.trip,
    required this.jumlahSinggahan,
    this.foto,
  });

  final Trip trip;
  final int jumlahSinggahan;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _LatarFoto(
      foto: foto,
      benih: 2,
      anak: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 100, 28, 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MunculBertahap(
                indeks: 0,
                child: Text(
                  'Sampai di sini',
                  style: text.displaySmall?.copyWith(
                    color: NapakColors.textOnDeep,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              MunculBertahap(
                indeks: 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AngkaBerjalan(
                      nilai: trip.distanceKm,
                      desimal: 1,
                      gaya: text.displaySmall?.copyWith(
                        color: NapakColors.textOnDeep,
                      ),
                    ),
                    Text(
                      '  km ditempuh',
                      style: text.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              MunculBertahap(
                indeks: 2,
                child: Text(
                  jumlahSinggahan == 0
                      ? 'Tanpa singgahan yang ditandai.'
                      : '$jumlahSinggahan singgahan ditandai sepanjang jalan.',
                  style: text.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ),

              const SizedBox(height: 32),
              MunculBertahap(
                indeks: 3,
                child: FilledButton.icon(
                  onPressed: () => VideoSheet.tampilkan(context, trip),
                  icon: const Icon(Icons.movie_creation_outlined, size: 20),
                  label: const Text('Jadikan video'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NapakColors.textOnDeep,
                    foregroundColor: NapakColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              MunculBertahap(
                indeks: 4,
                child: Text(
                  'Cerita ini tidak hilang dalam 24 jam. Buka lagi kapan pun '
                  'kamu ingin menyusurinya.',
                  style: text.bodySmall?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Galat extends StatelessWidget {
  const _Galat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          pesan,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: NapakColors.textOnDeep),
        ),
      ),
    );
  }
}
