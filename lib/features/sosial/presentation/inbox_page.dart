import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../data/sosial_models.dart';
import '../data/sosial_repository.dart';
import 'komponen_sosial.dart';

/// Inbox.
///
/// Isinya hanya hal yang terjadi karena perbuatan orang lain atau perbuatan
/// pemiliknya sendiri — tidak ada pengumuman dari pembuat aplikasi. Inbox
/// yang dipakai beriklan pelan-pelan tidak dibuka orang, lalu undangan
/// temannya sendiri ikut tidak terbaca.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  /// Kabar yang sudah dibuang di layar, sebelum server menjawab — supaya
  /// Dismissible tidak mengeluh barisnya masih ada di daftar.
  final _dibuang = <String>{};

  Future<void> _buka(Kabar k) async {
    if (!k.sudahDibaca) {
      await ref.read(sosialRepositoryProvider).tandaiDibaca(k.id);
      ref.invalidate(inboxProvider);
    }
    final tautan = k.tautan;
    if (tautan == null || tautan == '/inbox' || !mounted) return;
    await context.push(tautan);
  }

  Future<void> _semuaDibaca() async {
    HapticFeedback.lightImpact();
    await ref.read(sosialRepositoryProvider).tandaiSemuaDibaca();
    ref.invalidate(inboxProvider);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final undangan = ref.watch(undanganMasukProvider);
    final adaBelum = inbox.value?.any((k) => !k.sudahDibaca) ?? false;

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      appBar: BilahEkspedisi(
        judul: 'Kabar',
        keterangan: adaBelum ? 'Ada yang belum dibaca' : 'Semua terbaca',
        aksi: [
          AnimatedOpacity(
            duration: TourvellaMotion.cepat,
            opacity: adaBelum ? 1 : 0,
            child: TextButton(
              onPressed: adaBelum ? _semuaDibaca : null,
              style: TextButton.styleFrom(
                foregroundColor: TourvellaColors.emberRedup,
              ),
              child: const Text('Tandai terbaca'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(inboxProvider)
            ..invalidate(undanganMasukProvider);
          await ref.read(inboxProvider.future);
        },
        child: inbox.when(
          loading: () => const KerangkaDaftarOrang(),
          error: (galat, _) => ListView(
            children: [
              KosongHangat(
                ikon: Icons.cloud_off_rounded,
                judul: 'Kabar belum bisa dimuat',
                isi: galat.toString(),
              ),
            ],
          ),
          data: (semua) {
            final daftar = semua
                .where((k) => !_dibuang.contains(k.id))
                .toList();
            final daftarUndangan = undangan.value ?? const <UndanganTrip>[];

            if (daftar.isEmpty && daftarUndangan.isEmpty) {
              return ListView(
                children: const [
                  KosongHangat(
                    ikon: Icons.mark_email_read_outlined,
                    judul: 'Tidak ada kabar baru',
                    isi:
                        'Undangan jalan bareng, kartu pos, dan video yang '
                        'selesai dibuat akan muncul di sini.',
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Undangan yang belum dijawab selalu di paling atas: cuma ini
                // yang menunggu keputusanmu.
                for (var i = 0; i < daftarUndangan.length; i++)
                  _KartuUndangan(u: daftarUndangan[i])
                      .animate(delay: (70 * i).ms)
                      .fadeIn(duration: TourvellaMotion.sedang)
                      .slideY(begin: 0.2, curve: TourvellaMotion.mengalir)
                      .then()
                      .shimmer(
                        duration: 1200.ms,
                        color: TourvellaColors.textOnDeep.withValues(
                          alpha: 0.35,
                        ),
                      ),
                if (daftarUndangan.isNotEmpty) const SizedBox(height: 10),

                for (var i = 0; i < daftar.length; i++)
                  Dismissible(
                    key: ValueKey(daftar[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: TourvellaColors.softSky,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: TourvellaColors.deepAccent,
                      ),
                    ),
                    onDismissed: (_) {
                      final id = daftar[i].id;
                      setState(() => _dibuang.add(id));
                      ref.read(sosialRepositoryProvider).buangKabar(id);
                    },
                    child: _BarisKabar(k: daftar[i], onTap: _buka)
                        .animate(delay: (40 * i.clamp(0, 10)).ms)
                        .fadeIn(duration: TourvellaMotion.sedang)
                        .slideX(begin: 0.05, curve: TourvellaMotion.mengalir),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ikon dan warna aksen tiap jenis kabar.
(IconData, Color) _gayaKabar(JenisKabar jenis) => switch (jenis) {
  JenisKabar.permintaanTeman => (
    Icons.person_add_alt_1_rounded,
    TourvellaColors.deepAccent,
  ),
  JenisKabar.temanDiterima => (
    Icons.handshake_outlined,
    TourvellaColors.affirm,
  ),
  JenisKabar.undanganTrip => (
    Icons.two_wheeler_rounded,
    TourvellaColors.deepAccent,
  ),
  JenisKabar.undanganDijawab => (
    Icons.event_available_rounded,
    TourvellaColors.affirm,
  ),
  JenisKabar.videoSiap => (
    Icons.movie_filter_outlined,
    TourvellaColors.deepAccent,
  ),
  JenisKabar.kartuPos => (
    Icons.local_post_office_outlined,
    TourvellaColors.attention,
  ),
  JenisKabar.pesanBaru => (
    Icons.chat_bubble_outline_rounded,
    TourvellaColors.primary,
  ),
  JenisKabar.kenangan => (Icons.history_rounded, TourvellaColors.attention),
  JenisKabar.salut => (Icons.front_hand_rounded, TourvellaColors.ember),
  JenisKabar.komentar => (
    Icons.mode_comment_outlined,
    TourvellaColors.deepAccent,
  ),
  JenisKabar.lain => (
    Icons.notifications_none_rounded,
    TourvellaColors.primary,
  ),
};

class _BarisKabar extends StatelessWidget {
  const _BarisKabar({required this.k, required this.onTap});

  final Kabar k;
  final ValueChanged<Kabar> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (ikon, warna) = _gayaKabar(k.jenis);

    return TourvellaPressable(
      onTap: () => onTap(k),
      skala: 0.985,
      child: AnimatedContainer(
        duration: TourvellaMotion.sedang,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: k.sudahDibaca ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: k.sudahDibaca
              ? null
              : [
                  BoxShadow(
                    color: TourvellaColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, size: 21, color: warna),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.judul,
                    style: text.titleSmall?.copyWith(
                      fontWeight: k.sudahDibaca ? null : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    k.isi,
                    style: text.bodyMedium?.copyWith(
                      color: TourvellaColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(waktuSantai(k.dibuat), style: text.bodySmall),
                ],
              ),
            ),
            // Titik belum dibaca yang berdenyut sekali saat muncul.
            if (!k.sudahDibaca)
              Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 6, left: 6),
                    decoration: const BoxDecoration(
                      color: TourvellaColors.deepAccent,
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    end: 1.35,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
          ],
        ),
      ),
    );
  }
}

class _KartuUndangan extends ConsumerStatefulWidget {
  const _KartuUndangan({required this.u});

  final UndanganTrip u;

  @override
  ConsumerState<_KartuUndangan> createState() => _KartuUndanganState();
}

class _KartuUndanganState extends ConsumerState<_KartuUndangan> {
  bool _sibuk = false;

  Future<void> _jawab(bool ikut) async {
    setState(() => _sibuk = true);
    HapticFeedback.mediumImpact();
    try {
      final hasil = await ref
          .read(sosialRepositoryProvider)
          .jawabUndangan(widget.u.id, ikut: ikut);
      ref
        ..invalidate(undanganMasukProvider)
        ..invalidate(inboxProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(hasil.pesan)));
      if (hasil.tripId != null) {
        await context.push('/trip/${hasil.tripId}/bareng');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: TourvellaColors.routeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.two_wheeler_rounded,
                color: TourvellaColors.textOnDeep,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.u.dari} mengajakmu',
                style: text.labelLarge?.copyWith(
                  color: TourvellaColors.textOnDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.u.judulTrip,
            style: text.titleLarge?.copyWith(color: TourvellaColors.textOnDeep),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _sibuk ? null : () => _jawab(false),
                style: TextButton.styleFrom(
                  foregroundColor: TourvellaColors.textOnDeep,
                ),
                child: const Text('Belum bisa'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sibuk ? null : () => _jawab(true),
                style: FilledButton.styleFrom(
                  backgroundColor: TourvellaColors.textOnDeep,
                  foregroundColor: TourvellaColors.deepAccent,
                ),
                child: const Text('Ikut'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
