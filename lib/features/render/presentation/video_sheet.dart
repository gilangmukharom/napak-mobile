import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/napak_ekspedisi.dart';
import '../../../core/providers.dart';
import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../trips/data/trip_models.dart';

/// Lembar pembuatan video animasi rute.
///
/// Rendering terjadi di server, jadi yang dilakukan layar ini hanya menitipkan
/// permintaan lalu menanyakan kabarnya berkala. Menutup lembar ini tidak
/// membatalkan apa pun — videonya tetap dikerjakan, dan bisa diambil lagi
/// nanti dari halaman perjalanan.
class VideoSheet extends ConsumerStatefulWidget {
  const VideoSheet({required this.trip, super.key});

  final Trip trip;

  static Future<void> tampilkan(BuildContext context, Trip trip) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VideoSheet(trip: trip),
    );
  }

  @override
  ConsumerState<VideoSheet> createState() => _VideoSheetState();
}

class _VideoSheetState extends ConsumerState<VideoSheet> {
  FormatRender _format = FormatRender.tegak;
  TemplateRender _template = TemplateRender.perjalanan;

  RenderJob? _job;
  Timer? _penanya;
  bool _meminta = false;
  bool _mengunduh = false;
  String? _kesalahan;

  VideoPlayerController? _pemutar;
  File? _berkasVideo;

  @override
  void initState() {
    super.initState();
    // Kalau sebelumnya sudah pernah minta video untuk perjalanan ini, tampilkan
    // yang terakhir daripada menyuruh orang menunggu dari nol lagi.
    unawaited(_muatTerakhir());
  }

  @override
  void dispose() {
    _penanya?.cancel();
    _pemutar?.dispose();
    super.dispose();
  }

  /// Unduh videonya sekali, lalu pakai berkas yang sama untuk ditonton dan
  /// dibagikan. Mengunduh dua kali untuk dua keperluan itu pemborosan yang
  /// paling terasa di kuota orang.
  Future<File> _pastikanTerunduh(RenderJob job) async {
    final sudah = _berkasVideo;
    if (sudah != null && await sudah.exists()) return sudah;

    final folder = await getTemporaryDirectory();
    final berkas = File('${folder.path}/napak-${job.id}.mp4');
    await ref.read(tripRepositoryProvider).unduhVideo(job.id, berkas.path);

    _berkasVideo = berkas;
    return berkas;
  }

  /// Siapkan pemutar begitu videonya jadi, tanpa menunggu diminta.
  ///
  /// Videonya cuma ratusan kilobyte, dan melihat hasilnya sebelum membagikan
  /// itu yang paling wajar diinginkan orang — bukan menekan "bagikan" sambil
  /// berharap.
  Future<void> _siapkanPratinjau(RenderJob job) async {
    if (_pemutar != null) return;

    try {
      final berkas = await _pastikanTerunduh(job);
      final pemutar = VideoPlayerController.file(berkas);
      await pemutar.initialize();
      await pemutar.setLooping(true);
      await pemutar.play();

      if (!mounted) {
        await pemutar.dispose();
        return;
      }
      setState(() => _pemutar = pemutar);
    } catch (_) {
      // Pratinjau itu bonus. Kalau gagal, tombol bagikan tetap jalan.
    }
  }

  Future<void> _muatTerakhir() async {
    try {
      final daftar = await ref
          .read(tripRepositoryProvider)
          .daftarRender(widget.trip.id);
      if (!mounted || daftar.isEmpty) return;
      setState(() => _job = daftar.first);
      if (daftar.first.sedangBerjalan) _mulaiMenanya();
    } catch (_) {
      // Tidak fatal: cukup mulai dari keadaan kosong.
    }
  }

  Future<void> _minta() async {
    await _pemutar?.dispose();
    setState(() {
      _meminta = true;
      _kesalahan = null;
      _pemutar = null;
      _berkasVideo = null;
    });

    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .mintaRender(widget.trip.id, format: _format, template: _template);
      if (!mounted) return;
      setState(() => _job = job);
      _mulaiMenanya();
    } catch (error) {
      if (!mounted) return;
      setState(() => _kesalahan = error.toString());
    } finally {
      if (mounted) setState(() => _meminta = false);
    }
  }

  /// Tanya kabar tiap 2 detik. Cukup jarang untuk tidak membebani, cukup
  /// sering supaya bilah kemajuannya terasa hidup.
  void _mulaiMenanya() {
    _penanya?.cancel();
    _penanya = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final id = _job?.id;
      if (id == null) return timer.cancel();

      try {
        final terbaru = await ref.read(tripRepositoryProvider).statusRender(id);
        if (!mounted) return timer.cancel();
        setState(() => _job = terbaru);

        if (!terbaru.sedangBerjalan) {
          timer.cancel();
          if (terbaru.siapDiunduh) unawaited(_siapkanPratinjau(terbaru));
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _unduhDanBagikan() async {
    final job = _job;
    if (job == null || !job.siapDiunduh) return;

    setState(() => _mengunduh = true);
    try {
      final berkas = await _pastikanTerunduh(job);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(berkas.path)],
          text: '${widget.trip.title} — direkam bersama Napak',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _kesalahan = error.toString());
    } finally {
      if (mounted) setState(() => _mengunduh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final job = _job;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jadikan video', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Rutemu digambar perlahan dari awal sampai akhir, lengkap dengan '
            'jarak dan lama perjalanan.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),

          const LabelKapital('Ukuran'),
          const SizedBox(height: 10),
          SegmentedButton<FormatRender>(
            segments: [
              for (final f in FormatRender.values)
                ButtonSegment(
                  value: f,
                  label: Text(f.rasio),
                  tooltip: f.keterangan,
                ),
            ],
            selected: {_format},
            onSelectionChanged: job?.sedangBerjalan ?? false
                ? null
                : (pilihan) => setState(() => _format = pilihan.first),
            style: _gayaSegmen(),
          ),
          const SizedBox(height: 20),

          const LabelKapital('Suasana'),
          const SizedBox(height: 10),
          SegmentedButton<TemplateRender>(
            segments: [
              for (final t in TemplateRender.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_template},
            onSelectionChanged: job?.sedangBerjalan ?? false
                ? null
                : (pilihan) => setState(() => _template = pilihan.first),
            style: _gayaSegmen(),
          ),
          if (_template == TemplateRender.mudik) ...[
            const SizedBox(height: 10),
            Text(
              'Template Mudik memakai warna hangat dan caption perjalanan '
              'pulang.',
              style: text.bodySmall,
            ),
          ],

          const SizedBox(height: 28),
          if (_pemutar != null) ...[
            _Pratinjau(pemutar: _pemutar!),
            const SizedBox(height: 20),
          ],
          if (job != null) _Kemajuan(job: job),
          if (_kesalahan != null) ...[
            const SizedBox(height: 14),
            Text(
              _kesalahan!,
              style: text.bodySmall?.copyWith(color: NapakColors.attention),
            ),
          ],

          const SizedBox(height: 20),
          if (job != null && job.siapDiunduh)
            FilledButton.icon(
              onPressed: _mengunduh ? null : _unduhDanBagikan,
              icon: _mengunduh
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NapakColors.textOnDeep,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(_mengunduh ? 'Menyiapkan...' : 'Bagikan video'),
            )
          else
            FilledButton(
              onPressed: (_meminta || (job?.sedangBerjalan ?? false))
                  ? null
                  : _minta,
              child: Text(
                job?.sedangBerjalan ?? false
                    ? 'Sedang digambar...'
                    : 'Buat video',
              ),
            ),

          if (job != null && job.siapDiunduh) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _minta,
              child: const Text('Buat ulang dengan pilihan lain'),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _gayaSegmen() => SegmentedButton.styleFrom(
    backgroundColor: NapakColors.softSky,
    selectedBackgroundColor: NapakColors.primary,
    selectedForegroundColor: NapakColors.textPrimary,
    foregroundColor: NapakColors.textSecondary,
  );
}

class _Kemajuan extends StatelessWidget {
  const _Kemajuan({required this.job});

  final RenderJob job;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (job.status == StatusRender.gagal) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NapakColors.warmNeutral,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          job.pesanGalat ?? 'Videonya gagal dibuat. Coba lagi ya.',
          style: text.bodySmall,
        ),
      );
    }

    if (job.siapDiunduh) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: NapakColors.affirm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Videonya siap${job.ukuranByte != null ? ' · ${_ukuran(job.ukuranByte!)}' : ''}',
              style: text.bodyMedium,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(job.status.label, style: text.bodyMedium),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: job.progress == 0 ? null : job.progress / 100,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  static String _ukuran(int byte) {
    if (byte < 1024 * 1024) return '${(byte / 1024).round()} KB';
    return '${(byte / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Pratinjau video yang berputar terus di dalam lembar ini.
///
/// Tanpa suara dan tanpa kontrol: durasinya cuma tujuh detik, dan yang ingin
/// dilihat orang adalah apakah rutenya tergambar bagus — bukan menggulir
/// maju-mundur di dalamnya.
class _Pratinjau extends StatelessWidget {
  const _Pratinjau({required this.pemutar});

  final VideoPlayerController pemutar;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NapakMotion.lambat,
      curve: NapakMotion.mengalir,
      builder: (context, t, anak) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + t * 0.06, child: anak),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            // Dibatasi tingginya supaya video tegak 9:16 tidak mendorong
            // tombol bagikan keluar layar.
            height: 260,
            child: AspectRatio(
              aspectRatio: pemutar.value.aspectRatio,
              child: VideoPlayer(pemutar),
            ),
          ),
        ),
      ),
    );
  }
}
