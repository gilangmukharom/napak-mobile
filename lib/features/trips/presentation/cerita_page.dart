import 'dart:async';

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
      backgroundColor: NapakColors.base,
      body: cerita.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    duration: NapakMotion.cepat,
                    child: KeyedSubtree(
                      key: ValueKey(_indeks),
                      child: sekarang,
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: NapakColors.textPrimary,
                          ),
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

    return [
      _RuasPembuka(trip: trip, titik: titik),
      for (final s in singgahan) _RuasSinggahan(titik: s, trip: trip),
      _RuasPenutup(trip: trip, jumlahSinggahan: singgahan.length),
    ];
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
                  backgroundColor: NapakColors.divider,
                  valueColor: const AlwaysStoppedAnimation(
                    NapakColors.deepAccent,
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
  const _RuasPembuka({required this.trip, required this.titik});

  final Trip trip;
  final List<TripPoint> titik;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 48),
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
              style: text.bodyMedium?.copyWith(
                color: NapakColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          MunculBertahap(
            indeks: 1,
            child: Text(trip.title, style: text.displaySmall),
          ),
          const SizedBox(height: 32),
          MunculBertahap(
            indeks: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: PratinjauRute(
                titik: [
                  for (final t in titik) (lat: t.lat, lng: t.lng),
                ],
                tinggi: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu singgahan: fotonya besar, catatannya di bawah.
class _RuasSinggahan extends StatelessWidget {
  const _RuasSinggahan({required this.titik, required this.trip});

  final TripPoint titik;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 92, 24, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titik.photoUrl != null)
            MunculBertahap(
              indeks: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.network(
                    titik.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, galat, jejak) => Container(
                      color: NapakColors.softSky,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: NapakColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (titik.photoUrl != null) const SizedBox(height: 22),

          MunculBertahap(
            indeks: 1,
            child: Row(
              children: [
                Text(
                  DateFormat('HH:mm').format(titik.recordedAt),
                  style: text.labelMedium?.copyWith(
                    color: NapakColors.deepAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(titik.transportMode.label, style: text.bodySmall),
              ],
            ),
          ),

          if (titik.note != null) ...[
            const SizedBox(height: 10),
            MunculBertahap(
              indeks: 2,
              child: Text(
                titik.note!,
                style: text.headlineSmall?.copyWith(height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuasPenutup extends StatelessWidget {
  const _RuasPenutup({required this.trip, required this.jumlahSinggahan});

  final Trip trip;
  final int jumlahSinggahan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MunculBertahap(
            indeks: 0,
            child: Text('Sampai di sini', style: text.displaySmall),
          ),
          const SizedBox(height: 28),

          MunculBertahap(
            indeks: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AngkaBerjalan(
                  nilai: trip.distanceKm,
                  desimal: 1,
                  gaya: text.displaySmall,
                ),
                Text('  km ditempuh', style: text.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MunculBertahap(
            indeks: 2,
            child: Text(
              jumlahSinggahan == 0
                  ? 'Tanpa singgahan yang ditandai.'
                  : '$jumlahSinggahan singgahan ditandai sepanjang jalan.',
              style: text.bodyLarge?.copyWith(
                color: NapakColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 44),
          MunculBertahap(
            indeks: 3,
            child: FilledButton.icon(
              onPressed: () => VideoSheet.tampilkan(context, trip),
              icon: const Icon(Icons.movie_creation_outlined, size: 20),
              label: const Text('Jadikan video'),
            ),
          ),
          const SizedBox(height: 16),
          MunculBertahap(
            indeks: 4,
            child: Text(
              'Cerita ini tidak hilang dalam 24 jam. Buka lagi kapan pun kamu '
              'ingin menyusurinya.',
              style: text.bodySmall,
            ),
          ),
        ],
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
