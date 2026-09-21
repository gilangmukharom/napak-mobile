import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/napak_colors.dart';
import '../../../core/theme/napak_motion.dart';
import '../../../core/widgets/napak_gerak.dart';
import '../../../core/widgets/napak_pressable.dart';
import '../../obrolan/data/obrolan_data.dart';
import '../data/sosial_models.dart';
import '../data/sosial_repository.dart';
import 'komponen_sosial.dart';

/// Teman.
///
/// Dicari lewat kode Napak, bukan nomor HP atau buku kontak. Menyapu buku
/// kontak memang cara tercepat mengisi daftar teman — dan juga cara tercepat
/// memberi tahu seluruh isi buku kontak siapa saja yang memakai aplikasi
/// perekam perjalanan.
class TemanPage extends ConsumerWidget {
  const TemanPage({super.key});

  Future<void> _segarkan(WidgetRef ref) async {
    ref
      ..invalidate(daftarTemanProvider)
      ..invalidate(permintaanMasukProvider)
      ..invalidate(permintaanTerkirimProvider);
    await ref.read(daftarTemanProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teman = ref.watch(daftarTemanProvider);
    final masuk = ref.watch(permintaanMasukProvider);
    final terkirim = ref.watch(permintaanTerkirimProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: NapakColors.base,
      appBar: AppBar(title: const Text('Teman')),
      body: RefreshIndicator(
        onRefresh: () => _segarkan(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const _KartuKodeSaya(),
            const SizedBox(height: 18),
            const _TambahTeman(),

            // --- Permintaan masuk ---
            ...masuk.maybeWhen(
              data: (daftar) => daftar.isEmpty
                  ? const <Widget>[]
                  : [
                      const SizedBox(height: 28),
                      _Judul(teks: 'Ingin berteman', jumlah: daftar.length),
                      for (var i = 0; i < daftar.length; i++)
                        _BarisPermintaan(p: daftar[i])
                            .animate(delay: (60 * i).ms)
                            .fadeIn(duration: NapakMotion.sedang)
                            .slideX(begin: 0.08, curve: NapakMotion.mengalir),
                    ],
              orElse: () => const <Widget>[],
            ),

            // --- Daftar teman ---
            const SizedBox(height: 28),
            _Judul(
              teks: 'Teman seperjalanan',
              jumlah: teman.value?.length ?? 0,
            ),
            teman.when(
              loading: () => const SizedBox(
                height: 260,
                child: KerangkaDaftarOrang(jumlah: 4),
              ),
              error: (galat, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(galat.toString(), style: text.bodyMedium),
              ),
              data: (daftar) => daftar.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Belum ada. Bagikan kodemu, atau masukkan kode temanmu '
                        'di atas.',
                        style: text.bodyMedium?.copyWith(
                          color: NapakColors.textSecondary,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < daftar.length; i++)
                          MunculBertahap(
                            indeks: i,
                            child: _BarisTeman(teman: daftar[i]),
                          ),
                      ],
                    ),
            ),

            // --- Menunggu dijawab ---
            ...terkirim.maybeWhen(
              data: (daftar) => daftar.isEmpty
                  ? const <Widget>[]
                  : [
                      const SizedBox(height: 28),
                      _Judul(teks: 'Menunggu dijawab', jumlah: daftar.length),
                      for (final p in daftar) _BarisTerkirim(p: p),
                    ],
              orElse: () => const <Widget>[],
            ),

            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: NapakColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Berteman tidak membuka perjalananmu. Jejakmu tetap '
                    'tertutup sampai kamu sendiri mengundang atau '
                    'membagikannya.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Judul extends StatelessWidget {
  const _Judul({required this.teks, required this.jumlah});

  final String teks;
  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(teks, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          if (jumlah > 0)
            Text(
              '$jumlah',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: NapakColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Kode Napak sendiri, besar, siap dibacakan atau dibagikan.
class _KartuKodeSaya extends ConsumerWidget {
  const _KartuKodeSaya();

  /// `ABCD2345` → `ABCD 2345`. Dua kelompok empat lebih mudah dibacakan
  /// lewat telepon daripada delapan huruf beruntun.
  static String _berkelompok(String kode) => kode.length == 8
      ? '${kode.substring(0, 4)} ${kode.substring(4)}'
      : kode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kode = ref.watch(kodeSayaProvider);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: NapakColors.routeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: NapakColors.deepAccent.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KODE NAPAKMU',
            style: text.labelSmall?.copyWith(
              color: NapakColors.textOnDeep.withValues(alpha: 0.8),
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: kode.when(
                  loading: () => Text(
                    '···· ····',
                    style: text.headlineMedium?.copyWith(
                      color: NapakColors.textOnDeep,
                    ),
                  ),
                  error: (e, _) => Text(
                    'Belum bisa dimuat',
                    style: text.bodyLarge?.copyWith(
                      color: NapakColors.textOnDeep,
                    ),
                  ),
                  // Hurufnya mendarat satu per satu, seperti papan jadwal
                  // di stasiun.
                  data: (k) => Row(
                    children: [
                      for (final (i, huruf) in _berkelompok(k).split('').indexed)
                        Text(
                              huruf,
                              style: text.headlineMedium?.copyWith(
                                color: NapakColors.textOnDeep,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                            )
                            .animate(delay: (45 * i).ms)
                            .fadeIn(duration: 200.ms)
                            .slideY(begin: -0.6, curve: NapakMotion.memantul),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Salin',
                color: NapakColors.textOnDeep,
                onPressed: kode.value == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: kode.value!));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kodemu tersalin.')),
                        );
                      },
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: 'Bagikan',
                color: NapakColors.textOnDeep,
                onPressed: kode.value == null
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Tambahkan aku di Napak biar bisa jalan bareng. '
                              'Kodeku: ${_berkelompok(kode.value!)}',
                        ),
                      ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bagikan ke orang yang memang kamu kenal. Kode ini cuma '
            'memperlihatkan namamu, bukan nomormu.',
            style: text.bodySmall?.copyWith(
              color: NapakColors.textOnDeep.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: NapakMotion.sedang).scaleXY(
      begin: 0.96,
      curve: NapakMotion.mengalir,
    );
  }
}

class _TambahTeman extends ConsumerStatefulWidget {
  const _TambahTeman();

  @override
  ConsumerState<_TambahTeman> createState() => _TambahTemanState();
}

class _TambahTemanState extends ConsumerState<_TambahTeman> {
  final _kode = TextEditingController();
  HasilCari? _hasil;
  String? _pesan;
  bool _sibuk = false;

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _cari() async {
    final kode = _kode.text.trim();
    if (kode.length < 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sibuk = true;
      _pesan = null;
      _hasil = null;
    });

    try {
      final hasil = await ref.read(sosialRepositoryProvider).cari(kode);
      setState(() => _hasil = hasil);
    } catch (error) {
      setState(() => _pesan = error.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _ajak() async {
    final hasil = _hasil;
    if (hasil == null) return;
    setState(() => _sibuk = true);
    try {
      final pesan = await ref.read(sosialRepositoryProvider).ajak(hasil.kode);
      HapticFeedback.mediumImpact();
      setState(() {
        _pesan = pesan;
        _hasil = null;
        _kode.clear();
      });
      ref
        ..invalidate(daftarTemanProvider)
        ..invalidate(permintaanTerkirimProvider)
        ..invalidate(permintaanMasukProvider);
    } catch (error) {
      setState(() => _pesan = error.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kode,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _cari(),
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s-]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  hintText: 'Masukkan kode Napak teman',
                  prefixIcon: Icon(Icons.person_search_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: NapakMotion.cepat,
              child: _sibuk
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : IconButton.filled(
                      onPressed: _kode.text.trim().length >= 6 ? _cari : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
            ),
          ],
        ),

        // Hasil pencarian meluncur masuk sebagai kartu kecil.
        AnimatedSize(
          duration: NapakMotion.sedang,
          curve: NapakMotion.mengalir,
          child: _hasil == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _KartuHasil(hasil: _hasil!, onAjak: _ajak)
                      .animate()
                      .fadeIn(duration: NapakMotion.cepat)
                      .slideY(begin: -0.15, curve: NapakMotion.memantul),
                ),
        ),

        AnimatedSize(
          duration: NapakMotion.cepat,
          child: _pesan == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Text(
                    _pesan!,
                    style: text.bodySmall?.copyWith(
                      color: NapakColors.deepAccent,
                    ),
                  ).animate().fadeIn(),
                ),
        ),
      ],
    );
  }
}

class _KartuHasil extends StatelessWidget {
  const _KartuHasil({required this.hasil, required this.onAjak});

  final HasilCari hasil;
  final VoidCallback onAjak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final (label, aktif) = switch (hasil.status) {
      'diri_sendiri' => ('Ini kamu', false),
      'diterima' => ('Sudah berteman', false),
      'menunggu' => ('Menunggu dijawab', false),
      _ => ('Ajak berteman', true),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NapakColors.softSky),
      ),
      child: Row(
        children: [
          LingkaranNama(nama: hasil.nama),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasil.nama, style: text.titleSmall),
                Text(hasil.kode, style: text.bodySmall),
              ],
            ),
          ),
          aktif
              ? FilledButton(onPressed: onAjak, child: Text(label))
              : Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: NapakColors.textSecondary,
                  ),
                ),
        ],
      ),
    );
  }
}

class _BarisPermintaan extends ConsumerStatefulWidget {
  const _BarisPermintaan({required this.p});

  final PermintaanTeman p;

  @override
  ConsumerState<_BarisPermintaan> createState() => _BarisPermintaanState();
}

class _BarisPermintaanState extends ConsumerState<_BarisPermintaan> {
  /// null = belum dijawab; true = diterima; false = ditolak.
  bool? _jawaban;

  Future<void> _jawab(bool terima) async {
    final repo = ref.read(sosialRepositoryProvider);
    HapticFeedback.selectionClick();
    setState(() => _jawaban = terima);

    try {
      if (terima) {
        await repo.terima(widget.p.id);
      } else {
        await repo.tolak(widget.p.id);
      }
      // Biarkan animasi jawabannya selesai dulu sebelum barisnya diganti.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      ref
        ..invalidate(permintaanMasukProvider)
        ..invalidate(daftarTemanProvider)
        ..invalidate(jumlahKabarProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _jawaban = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          LingkaranNama(nama: widget.p.orang.nama),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.p.orang.nama, style: text.titleSmall),
                Text(
                  'ingin berteman · ${waktuSantai(widget.p.dibuat)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: NapakMotion.sedang,
            switchInCurve: NapakMotion.memantul,
            transitionBuilder: (anak, a) =>
                ScaleTransition(scale: a, child: anak),
            child: switch (_jawaban) {
              true => const Row(
                key: ValueKey('terima'),
                children: [
                  Icon(Icons.check_circle_rounded, color: NapakColors.affirm),
                  SizedBox(width: 6),
                  Text('Berteman'),
                ],
              ),
              false => const Text('Dilewati', key: ValueKey('tolak')),
              null => Row(
                key: const ValueKey('tanya'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _jawab(false),
                    child: const Text('Lewati'),
                  ),
                  FilledButton(
                    onPressed: () => _jawab(true),
                    child: const Text('Terima'),
                  ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _BarisTerkirim extends ConsumerWidget {
  const _BarisTerkirim({required this.p});

  final PermintaanTeman p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Opacity(opacity: 0.6, child: LingkaranNama(nama: p.orang.nama)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.orang.nama,
              style: text.bodyMedium?.copyWith(
                color: NapakColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sosialRepositoryProvider).tolak(p.id);
              ref.invalidate(permintaanTerkirimProvider);
            },
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }
}

class _BarisTeman extends ConsumerWidget {
  const _BarisTeman({required this.teman});

  final Teman teman;

  Future<void> _obrolan(BuildContext context, WidgetRef ref) async {
    try {
      final id = await ref
          .read(obrolanRepositoryProvider)
          .mulaiDengan(teman.id);
      if (!context.mounted) return;
      await context.push(
        '/obrolan/$id',
        extra: (judul: teman.nama, rombongan: false),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _lepas(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lepas ${teman.nama}?'),
        content: const Text(
          'Kalian tidak lagi bisa saling mengundang atau mengobrol. '
          'Dia tidak akan dikabari.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await ref.read(sosialRepositoryProvider).putuskan(teman.id);
    ref.invalidate(daftarTemanProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return NapakPressable(
      onTap: () => _obrolan(context, ref),
      onLongPress: () => _lepas(context, ref),
      skala: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            LingkaranNama(nama: teman.nama, ukuran: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(teman.nama, style: text.titleSmall),
                  if (teman.sejak != null)
                    Text(
                      'berteman sejak ${waktuSantai(teman.sejak!)}',
                      style: text.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Kirim pesan',
              onPressed: () => _obrolan(context, ref),
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: NapakColors.deepAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
