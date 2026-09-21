import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';

/// Satu media untuk ditampilkan layar penuh.
class MediaTampil {
  const MediaTampil({
    required this.id,
    required this.url,
    required this.video,
    this.posterUrl,
    this.judul,
    this.catatan,
    this.tempat,
    this.pada,
    this.tripId,
  });

  final String id;
  final String url;
  final bool video;
  final String? posterUrl;
  final String? judul;
  final String? catatan;
  final String? tempat;
  final DateTime? pada;
  final String? tripId;

  String get gambarDiam => video ? (posterUrl ?? '') : url;
  String get tagHero => 'media-$id';
}

/// Penampil media layar penuh: geser kiri-kanan, cubit untuk memperbesar,
/// geser ke bawah untuk menutup.
class PenampilMedia extends StatefulWidget {
  const PenampilMedia({required this.daftar, required this.awal, super.key});

  final List<MediaTampil> daftar;
  final int awal;

  static Future<void> buka(
    BuildContext context,
    List<MediaTampil> daftar,
    int awal,
  ) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: NapakMotion.sedang,
      reverseTransitionDuration: NapakMotion.cepat,
      pageBuilder: (context, a, b) =>
          PenampilMedia(daftar: daftar, awal: awal),
      transitionsBuilder: (context, a, b, anak) =>
          FadeTransition(opacity: a, child: anak),
    ),
  );

  @override
  State<PenampilMedia> createState() => _PenampilMediaState();
}

class _PenampilMediaState extends State<PenampilMedia> {
  late final PageController _halaman = PageController(
    initialPage: widget.awal,
  );
  late int _indeks = widget.awal;
  double _geserBawah = 0;
  bool _tampilkanKeterangan = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _halaman.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sekarang = widget.daftar[_indeks];
    final redup = (1 - (_geserBawah.abs() / 400)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: redup),
      body: GestureDetector(
        onTap: () =>
            setState(() => _tampilkanKeterangan = !_tampilkanKeterangan),
        onVerticalDragUpdate: (d) =>
            setState(() => _geserBawah += d.delta.dy),
        onVerticalDragEnd: (d) {
          if (_geserBawah.abs() > 140 || (d.primaryVelocity ?? 0).abs() > 900) {
            Navigator.of(context).pop();
          } else {
            setState(() => _geserBawah = 0);
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _geserBawah),
              child: Transform.scale(
                scale: 1 - (_geserBawah.abs() / 2400),
                child: PageView.builder(
                  controller: _halaman,
                  itemCount: widget.daftar.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _indeks = i);
                  },
                  itemBuilder: (context, i) {
                    final m = widget.daftar[i];
                    return Hero(
                      tag: m.tagHero,
                      child: m.video
                          ? _PemutarVideo(media: m, aktif: i == _indeks)
                          : InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              child: Image.network(
                                m.url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, anak, kemajuan) =>
                                    kemajuan == null
                                    ? anak
                                    : const Center(
                                        child: CircularProgressIndicator(
                                          color: NapakColors.primary,
                                        ),
                                      ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),

            // Bilah atas: tutup dan posisi.
            SafeArea(
              child: AnimatedOpacity(
                duration: NapakMotion.cepat,
                opacity: _tampilkanKeterangan && _geserBawah == 0 ? 1 : 0,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: NapakColors.textOnDeep,
                    ),
                    const Spacer(),
                    if (widget.daftar.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          '${_indeks + 1} / ${widget.daftar.length}',
                          style: const TextStyle(
                            color: NapakColors.textOnDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Keterangan di bawah: tempat, waktu, catatan, perjalanannya.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: NapakMotion.cepat,
                opacity: _tampilkanKeterangan && _geserBawah == 0 ? 1 : 0,
                child: _Keterangan(
                  key: ValueKey(sekarang.id),
                  media: sekarang,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({required this.media, super.key});

  final MediaTampil media;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final putih = NapakColors.textOnDeep;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        40,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (media.tempat != null || media.pada != null)
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: NapakColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  [
                    ?media.tempat,
                    if (media.pada != null)
                      DateFormat('d MMM yyyy · HH:mm', 'id_ID').format(
                        media.pada!,
                      ),
                  ].join(' · '),
                  style: text.labelMedium?.copyWith(
                    color: putih.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          if (media.catatan != null) ...[
            const SizedBox(height: 6),
            Text(
              media.catatan!,
              style: text.bodyLarge?.copyWith(color: putih, height: 1.4),
            ),
          ],
          if (media.tripId != null && media.judul != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/trip/${media.tripId}');
              },
              child: Row(
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 16,
                    color: putih.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    media.judul!,
                    style: text.labelLarge?.copyWith(
                      color: putih,
                      decoration: TextDecoration.underline,
                      decorationColor: putih.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: NapakMotion.cepat).slideY(begin: 0.1);
  }
}

/// Video yang diputar begitu halamannya aktif, berhenti saat digeser pergi.
class _PemutarVideo extends StatefulWidget {
  const _PemutarVideo({required this.media, required this.aktif});

  final MediaTampil media;
  final bool aktif;

  @override
  State<_PemutarVideo> createState() => _PemutarVideoState();
}

class _PemutarVideoState extends State<_PemutarVideo> {
  VideoPlayerController? _c;
  bool _siap = false;
  bool _jeda = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.media.url));
    _c = c;
    unawaited(
      c.initialize().then((_) {
        if (!mounted) return;
        c.setLooping(true);
        setState(() => _siap = true);
        if (widget.aktif) c.play();
      }),
    );
  }

  @override
  void didUpdateWidget(covariant _PemutarVideo lama) {
    super.didUpdateWidget(lama);
    if (!_siap) return;
    widget.aktif ? _c?.play() : _c?.pause();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Poster tampil selama videonya disiapkan, supaya layarnya tidak
        // hitam kosong.
        if (!_siap && widget.media.posterUrl != null)
          Positioned.fill(
            child: Image.network(widget.media.posterUrl!, fit: BoxFit.contain),
          ),
        if (_siap && c != null)
          GestureDetector(
            onLongPressStart: (_) {
              c.pause();
              setState(() => _jeda = true);
            },
            onLongPressEnd: (_) {
              c.play();
              setState(() => _jeda = false);
            },
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
        if (!_siap)
          const CircularProgressIndicator(color: NapakColors.primary),
        if (_siap && _jeda)
          const Icon(
            Icons.pause_circle_filled_rounded,
            size: 64,
            color: Colors.white70,
          ).animate().scaleXY(begin: 0.6, curve: NapakMotion.memantul),
        if (_siap && c != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: NapakColors.primary,
                bufferedColor: NapakColors.textOnDeep.withValues(alpha: 0.3),
                backgroundColor: NapakColors.textOnDeep.withValues(alpha: 0.1),
              ),
            ),
          ),
      ],
    );
  }
}
