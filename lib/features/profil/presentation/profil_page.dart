import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/tourvella_tekstur.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../../../core/widgets/tourvella_skeleton.dart';
import '../../garasi/data/garasi_data.dart';
import '../../garasi/presentation/garasi_view.dart';
import '../../obrolan/data/obrolan_data.dart';
import '../../sosial/data/sosial_repository.dart';
import '../../sosial/presentation/komponen_sosial.dart';
import '../../trips/data/trip_models.dart';
import '../data/profil_data.dart';
import 'penampil_media.dart';

/// Profil — milik sendiri atau orang lain.
///
/// Tata letaknya meminjam dari aplikasi galeri foto yang sudah hafal di jari
/// orang: foto profil, angka, bio, sorotan, lalu kisi tiga kolom. Isinya
/// tetap Tourvella: angkanya kilometer dan provinsi, sorotannya adalah Cerita
/// Perjalanan, dan kisinya hanya berisi yang pemiliknya sendiri pilih untuk
/// dipajang.
class ProfilPage extends ConsumerStatefulWidget {
  /// `saya` untuk profil sendiri.
  const ProfilPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends ConsumerState<ProfilPage> {
  int _tab = 0;

  Future<void> _segarkan() async {
    ref
      ..invalidate(profilProvider(widget.id))
      ..invalidate(dokumentasiProvider(_idNyata ?? widget.id))
      ..invalidate(perjalananProfilProvider(_idNyata ?? widget.id))
      ..invalidate(garasiProvider(widget.id == 'saya' ? 'saya' : widget.id));
    await ref.read(profilProvider(widget.id).future);
  }

  /// Id sungguhan pemilik profil — `saya` baru diketahui setelah dimuat.
  String? get _idNyata => ref.read(profilProvider(widget.id)).value?.id;

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider(widget.id));

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      body: profil.when(
        loading: () => const _KerangkaProfil(),
        error: (galat, _) => Center(
          child: KosongHangat(
            ikon: Icons.person_off_outlined,
            judul: 'Profilnya belum bisa dibuka',
            isi: galat.toString(),
          ),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: _segarkan,
          child: CustomScrollView(
            slivers: [
              _BilahAtas(profil: p, bisaKembali: widget.id != 'saya'),
              SliverToBoxAdapter(child: _Kepala(profil: p)),
              if (p.terbuka) ...[
                SliverToBoxAdapter(child: _Sorotan(id: p.id)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabDelegasi(
                    tab: _tab,
                    onGanti: (i) => setState(() => _tab = i),
                  ),
                ),
                switch (_tab) {
                  0 => _KisiDokumentasi(id: p.id, diriSendiri: p.diriSendiri),
                  1 => _DaftarPerjalanan(id: p.id),
                  _ => SliverGarasi(
                    pemilikId: p.id,
                    diriSendiri: p.diriSendiri,
                  ),
                },
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ] else
                SliverToBoxAdapter(child: _Tertutup(profil: p)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BilahAtas extends StatelessWidget {
  const _BilahAtas({required this.profil, required this.bisaKembali});

  final Profil profil;
  final bool bisaKembali;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: TourvellaColors.malam,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TourvellaColors.base,
      automaticallyImplyLeading: bisaKembali,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profil.diriSendiri)
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: TourvellaColors.base.withValues(alpha: 0.6),
            ),
          if (profil.diriSendiri) const SizedBox(width: 6),
          Flexible(
            child: Text(
              profil.nama,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: TourvellaColors.base,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (profil.diriSendiri) ...[
          IconButton(
            tooltip: 'Peta offline',
            onPressed: () => context.push('/peta-offline'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: 'Teman',
            onPressed: () => context.push('/teman'),
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan & privasi',
            onPressed: () => context.push('/pengaturan'),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ],
    );
  }
}

class _Kepala extends ConsumerWidget {
  const _Kepala({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final s = profil.statistik;

    // Halaman paspor: kanvas malam berkontur, stempel foto di kiri, angka
    // perjalanan di kanan. Yang di bawahnya — kisi foto — tetap terang,
    // jadi fotonya yang bersuara, bukan latarnya.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: TourvellaColors.kanvasMalam,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: KonturTopografi(opasitas: 0.2, jumlahGaris: 4, benih: 9),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FotoProfil(
                      nama: profil.nama,
                      url: profil.fotoUrl,
                      ukuran: 88,
                      cincin: true,
                    ).animate().scaleXY(
                      begin: 0.8,
                      duration: TourvellaMotion.lambat,
                      curve: TourvellaMotion.memantul,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: s == null
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Angka(
                                  nilai: s.perjalanan.toDouble(),
                                  label: 'perjalanan',
                                ),
                                _Angka(
                                  nilai: s.km,
                                  label: 'km',
                                  desimal: s.km < 100 ? 1 : 0,
                                ),
                                _Angka(
                                  nilai: s.provinsi.toDouble(),
                                  label: 'provinsi',
                                ),
                                _Angka(
                                  nilai: s.teman.toDouble(),
                                  label: 'teman',
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  profil.nama,
                  style: text.titleMedium?.copyWith(
                    color: TourvellaColors.base,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profil.bio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profil.bio!,
                    style: text.bodyMedium?.copyWith(
                      height: 1.4,
                      color: TourvellaColors.base.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (profil.kodeTourvella != null) ...[
                  const SizedBox(height: 10),
                  _KepingKode(kode: profil.kodeTourvella!),
                ],
                const SizedBox(height: 18),
                _TombolAksi(profil: profil),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.nilai, required this.label, this.desimal = 0});

  final double nilai;
  final String label;
  final int desimal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Odometer(
          nilai: nilai,
          desimal: desimal,
          gaya: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: TourvellaColors.ember,
          ),
        ),
        const SizedBox(height: 2),
        LabelKapital(
          label,
          warna: TourvellaColors.base.withValues(alpha: 0.55),
          ukuran: 9,
        ),
      ],
    );
  }
}

class _KepingKode extends StatelessWidget {
  const _KepingKode({required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: kode));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kode Tourvella-mu tersalin.')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: TourvellaColors.ember.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: TourvellaColors.ember.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tag_rounded,
              size: 14,
              color: TourvellaColors.ember,
            ),
            const SizedBox(width: 4),
            Text(
              kode,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: TourvellaColors.ember,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TombolAksi extends ConsumerStatefulWidget {
  const _TombolAksi({required this.profil});

  final Profil profil;

  @override
  ConsumerState<_TombolAksi> createState() => _TombolAksiState();
}

class _TombolAksiState extends ConsumerState<_TombolAksi> {
  bool _sibuk = false;

  Future<void> _jalankan(Future<void> Function() aksi) async {
    setState(() => _sibuk = true);
    try {
      await aksi();
      HapticFeedback.mediumImpact();
      ref.invalidate(profilProvider(widget.profil.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _obrolan() async {
    final id = await ref
        .read(obrolanRepositoryProvider)
        .mulaiDengan(widget.profil.id);
    if (!mounted) return;
    await context.push(
      '/obrolan/$id',
      extra: (judul: widget.profil.nama, rombongan: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profil;
    final sosial = ref.read(sosialRepositoryProvider);

    Widget kiri;
    Widget? kanan;

    switch (p.hubungan) {
      case Hubungan.diriSendiri:
        kiri = _Tombol(
          label: 'Edit profil',
          onTap: () async {
            await context.push('/profil/edit');
            ref.invalidate(profilProvider('saya'));
          },
        );
        kanan = _Tombol(
          label: 'Bagikan kode',
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text:
                  'Tambahkan aku di Tourvella biar bisa jalan bareng. '
                  'Kodeku: ${p.kodeTourvella}',
            ),
          ),
        );
      case Hubungan.teman:
        kiri = _Tombol(label: 'Kirim pesan', utama: true, onTap: _obrolan);
        kanan = _Tombol(
          label: 'Berteman',
          ikon: Icons.check_rounded,
          onTap: () {},
        );
      case Hubungan.menungguSaya:
        kiri = _Tombol(
          label: 'Terima pertemanan',
          utama: true,
          onTap: _sibuk
              ? null
              : () => _jalankan(() => sosial.terima(p.permintaanId!)),
        );
        kanan = _Tombol(
          label: 'Lewati',
          onTap: _sibuk
              ? null
              : () => _jalankan(() => sosial.tolak(p.permintaanId!)),
        );
      case Hubungan.menungguDia:
        kiri = _Tombol(
          label: 'Menunggu dijawab',
          ikon: Icons.schedule_rounded,
          onTap: _sibuk
              ? null
              : () => _jalankan(() => sosial.tolak(p.permintaanId!)),
        );
      case Hubungan.belum:
        kiri = const _Tombol(
          label: 'Minta kode Tourvella-nya untuk berteman',
          onTap: null,
        );
    }

    return Row(
      children: [
        Expanded(child: kiri),
        if (kanan != null) ...[
          const SizedBox(width: 8),
          Expanded(child: kanan),
        ],
      ],
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.label,
    required this.onTap,
    this.utama = false,
    this.ikon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool utama;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final anak = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ikon != null) ...[Icon(ikon, size: 16), const SizedBox(width: 6)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    // Tombolnya duduk di atas panel paspor yang gelap: yang utama diisi
    // bara, sisanya cuma garis. Tombol tonal pastel di sana terbaca seperti
    // tambalan terang di tengah malam.
    final gaya = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return utama
        ? FilledButton(
            onPressed: onTap,
            style: gaya.copyWith(
              backgroundColor: const WidgetStatePropertyAll(
                TourvellaColors.ember,
              ),
              foregroundColor: const WidgetStatePropertyAll(
                TourvellaColors.malam,
              ),
            ),
            child: anak,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: gaya.copyWith(
              foregroundColor: const WidgetStatePropertyAll(
                TourvellaColors.base,
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: TourvellaColors.kontur),
              ),
            ),
            child: anak,
          );
  }
}

/// Sorotan: lingkaran sampul tiap perjalanan yang dipajang — mengetuknya
/// membuka Cerita Perjalanannya, seperti sorotan di aplikasi galeri.
class _Sorotan extends ConsumerWidget {
  const _Sorotan({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perjalanan = ref.watch(perjalananProfilProvider(id));
    final daftar = (perjalanan.value ?? const <Trip>[])
        .where((t) => t.diProfil && !t.isRecording)
        .take(12)
        .toList();

    if (daftar.isEmpty) return const SizedBox(height: 12);

    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: daftar.length,
        separatorBuilder: (context, i) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final t = daftar[i];
          return TourvellaPressable(
                onTap: () => context.push('/trip/${t.id}/cerita'),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: TourvellaColors.routeGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: TourvellaColors.base,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: t.coverUrl == null
                                  ? const ColoredBox(
                                      color: TourvellaColors.softSky,
                                      child: Icon(
                                        Icons.route_rounded,
                                        color: TourvellaColors.deepAccent,
                                      ),
                                    )
                                  : Image.network(
                                      t.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) =>
                                          const ColoredBox(
                                            color: TourvellaColors.softSky,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              )
              .animate(delay: (50 * i).ms)
              .fadeIn(duration: TourvellaMotion.sedang)
              .scaleXY(begin: 0.7, curve: TourvellaMotion.memantul);
        },
      ),
    );
  }
}

class _TabDelegasi extends SliverPersistentHeaderDelegate {
  _TabDelegasi({required this.tab, required this.onGanti});

  final int tab;
  final ValueChanged<int> onGanti;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    return Container(
      color: TourvellaColors.base,
      child: LayoutBuilder(
        builder: (context, batas) {
          final lebar = batas.maxWidth / 3;
          return Stack(
            children: [
              Row(
                children: [
                  // Foto perjalanan, daftar perjalanan, dan garasi —
                  // tiga bagian terpisah, seperti tab di aplikasi galeri.
                  for (final (i, ikon) in [
                    Icons.grid_on_rounded,
                    Icons.route_outlined,
                    Icons.garage_outlined,
                  ].indexed)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onGanti(i);
                        },
                        child: SizedBox(
                          height: 48,
                          child: Icon(
                            ikon,
                            color: tab == i
                                ? TourvellaColors.textPrimary
                                : TourvellaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: TourvellaColors.divider),
              ),
              // Garis penanda tab meluncur, bukan melompat.
              AnimatedPositioned(
                duration: TourvellaMotion.sedang,
                curve: TourvellaMotion.mengalir,
                left: tab * lebar + lebar * 0.2,
                width: lebar * 0.6,
                bottom: 0,
                height: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: TourvellaColors.textPrimary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabDelegasi lama) => lama.tab != tab;
}

/// Kisi tiga kolom foto dan video.
class _KisiDokumentasi extends ConsumerWidget {
  const _KisiDokumentasi({required this.id, required this.diriSendiri});

  final String id;
  final bool diriSendiri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dok = ref.watch(dokumentasiProvider(id));

    return dok.when(
      loading: () => SliverGrid.count(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: [
          for (var i = 0; i < 9; i++)
            const TourvellaSkeleton(tinggi: double.infinity, radius: 0),
        ],
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString()),
        ),
      ),
      data: (daftar) {
        if (daftar.isEmpty) {
          return SliverToBoxAdapter(
            child: KosongHangat(
              ikon: Icons.photo_camera_back_outlined,
              judul: diriSendiri
                  ? 'Belum ada dokumentasi'
                  : 'Belum ada yang dipajang',
              isi: diriSendiri
                  ? 'Foto dan video yang kamu ambil saat singgah akan tersusun di sini.'
                  : 'Perjalanan yang dia pajang akan muncul di sini.',
            ),
          );
        }

        final media = [for (final d in daftar) d.tampil];

        return SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 3 / 4,
          ),
          itemCount: daftar.length,
          itemBuilder: (context, i) =>
              _Petak(
                    d: daftar[i],
                    diriSendiri: diriSendiri,
                    onTap: () => PenampilMedia.buka(context, media, i),
                  )
                  .animate(delay: (30 * (i % 12)).ms)
                  .fadeIn(duration: TourvellaMotion.sedang)
                  .scaleXY(begin: 0.92, curve: TourvellaMotion.mengalir),
        );
      },
    );
  }
}

class _Petak extends StatelessWidget {
  const _Petak({
    required this.d,
    required this.diriSendiri,
    required this.onTap,
  });

  final Dokumentasi d;
  final bool diriSendiri;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gambar = d.video ? d.posterUrl : d.url;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: d.tampil.tagHero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: TourvellaColors.softSky),
            if (gambar != null)
              Image.network(
                gambar,
                fit: BoxFit.cover,
                frameBuilder: (context, anak, frame, sinkron) => sinkron
                    ? anak
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: TourvellaMotion.sedang,
                        child: anak,
                      ),
                // Poster video yang belum sempat dibuat server tampil sebagai
                // kotak bergradasi, bukan ikon rusak.
                errorBuilder: (c, e, s) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: TourvellaColors.routeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            if (d.video)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 20,
                  color: TourvellaColors.textOnDeep,
                  shadows: [Shadow(blurRadius: 8, color: Color(0x66000000))],
                ),
              ),
            // Untuk pemiliknya: tanda mana yang hanya dilihat sendiri.
            if (diriSendiri && !d.dipajang)
              const Positioned(
                bottom: 6,
                left: 6,
                child: Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: TourvellaColors.textOnDeep,
                  shadows: [Shadow(blurRadius: 8, color: Color(0x66000000))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tab kedua: perjalanan sebagai kartu bersampul, dua kolom.
class _DaftarPerjalanan extends ConsumerWidget {
  const _DaftarPerjalanan({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(perjalananProfilProvider(id));
    final text = Theme.of(context).textTheme;

    return daftar.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
      data: (trips) => trips.isEmpty
          ? const SliverToBoxAdapter(
              child: KosongHangat(
                ikon: Icons.route_outlined,
                judul: 'Belum ada perjalanan',
                isi: 'Perjalanan yang dipajang akan muncul di sini.',
              ),
            )
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: trips.length,
                itemBuilder: (context, i) {
                  final t = trips[i];
                  return TourvellaPressable(
                        onTap: () => context.push('/trip/${t.id}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ColoredBox(color: TourvellaColors.softSky),
                              if (t.coverUrl != null)
                                Image.network(t.coverUrl!, fit: BoxFit.cover),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x00000000),
                                      Color(0xB3000000),
                                    ],
                                    stops: [0.45, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleSmall?.copyWith(
                                        color: TourvellaColors.textOnDeep,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.distanceKm.toStringAsFixed(t.distanceKm < 100 ? 1 : 0)} km',
                                      style: text.labelSmall?.copyWith(
                                        color: TourvellaColors.textOnDeep
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t.isOwner && !t.diProfil)
                                const Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 16,
                                    color: TourvellaColors.textOnDeep,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .animate(delay: (50 * (i % 8)).ms)
                      .fadeIn(duration: TourvellaMotion.sedang)
                      .slideY(begin: 0.1, curve: TourvellaMotion.mengalir);
                },
              ),
            ),
    );
  }
}

class _Tertutup extends StatelessWidget {
  const _Tertutup({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Container(height: 1, color: TourvellaColors.divider),
          KosongHangat(
            ikon: Icons.lock_outline_rounded,
            judul: 'Jejak ${profil.nama.split(' ').first} tertutup',
            isi: 'Hanya teman yang bisa melihat perjalanan yang dia pajang.',
          ),
        ],
      ),
    );
  }
}

class _KerangkaProfil extends StatelessWidget {
  const _KerangkaProfil();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                TourvellaSkeleton(tinggi: 88, lebar: 88, radius: 44),
                SizedBox(width: 18),
                Expanded(child: TourvellaSkeleton(tinggi: 44)),
              ],
            ),
            const SizedBox(height: 16),
            const TourvellaSkeleton.teks(lebar: 140),
            const SizedBox(height: 8),
            const TourvellaSkeleton.teks(lebar: 240),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 9; i++)
                    const TourvellaSkeleton(tinggi: double.infinity, radius: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto profil bulat, dengan cincin gradasi. Jatuh ke inisial kalau belum
/// ada fotonya.
class FotoProfil extends StatelessWidget {
  const FotoProfil({
    required this.nama,
    required this.url,
    this.ukuran = 44,
    this.cincin = false,
    super.key,
  });

  final String nama;
  final String? url;
  final double ukuran;
  final bool cincin;

  @override
  Widget build(BuildContext context) {
    final isi = url == null
        ? LingkaranNama(nama: nama, ukuran: ukuran)
        : ClipOval(
            child: Image.network(
              url!,
              width: ukuran,
              height: ukuran,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  LingkaranNama(nama: nama, ukuran: ukuran),
            ),
          );

    if (!cincin) return isi;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            TourvellaColors.deepAccent,
            TourvellaColors.primary,
            TourvellaColors.warmNeutral,
            TourvellaColors.deepAccent,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: TourvellaColors.base,
          shape: BoxShape.circle,
        ),
        child: isi,
      ),
    );
  }
}
