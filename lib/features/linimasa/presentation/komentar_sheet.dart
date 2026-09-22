import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../profil/presentation/profil_page.dart' show FotoProfil;
import '../data/linimasa_data.dart';

/// Komentar di satu perjalanan yang dipajang.
///
/// Hanya teman dan rombongan yang bisa membuka ini — penonton tautan publik
/// tidak melihat komentar sama sekali. Pemilik perjalanan bisa menghapus
/// komentar siapa pun di perjalanannya: moderasinya ada di tangan orang yang
/// jejaknya dikomentari.
class KomentarSheet extends ConsumerStatefulWidget {
  const KomentarSheet({required this.post, super.key});

  final PostLinimasa post;

  /// Buka lembarnya. Mengembalikan jumlah komentar terbaru supaya kartunya
  /// ikut berubah tanpa memuat ulang seluruh linimasa.
  static Future<int?> tampilkan(BuildContext context, PostLinimasa post) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TourvellaColors.base,
      builder: (_) => KomentarSheet(post: post),
    );
  }

  @override
  ConsumerState<KomentarSheet> createState() => _KomentarSheetState();
}

class _KomentarSheetState extends ConsumerState<KomentarSheet> {
  final _tulisan = TextEditingController();
  final _gulir = ScrollController();
  List<Komentar>? _daftar;
  String? _galat;
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _tulisan.dispose();
    _gulir.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final daftar = await ref
          .read(linimasaRepositoryProvider)
          .komentar(widget.post.tripId);
      if (mounted) setState(() => _daftar = daftar);
    } catch (error) {
      if (mounted) setState(() => _galat = error.toString());
    }
  }

  Future<void> _kirim() async {
    final isi = _tulisan.text.trim();
    if (isi.isEmpty || _mengirim) return;
    setState(() => _mengirim = true);
    try {
      final baru = await ref
          .read(linimasaRepositoryProvider)
          .tulisKomentar(widget.post.tripId, isi);
      HapticFeedback.lightImpact();
      _tulisan.clear();
      setState(() => _daftar = [...?_daftar, baru]);
      await Future<void>.delayed(TourvellaMotion.kilat);
      if (_gulir.hasClients) {
        await _gulir.animateTo(
          _gulir.position.maxScrollExtent,
          duration: TourvellaMotion.sedang,
          curve: TourvellaMotion.mengalir,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  Future<void> _hapus(Komentar k) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: TourvellaColors.base,
        title: const Text('Hapus komentar ini?'),
        content: Text(
          k.milikSendiri
              ? 'Komentarmu dihapus sungguhan, bukan disembunyikan.'
              : 'Ini perjalananmu, jadi kamu boleh menghapus komentar '
                    '${k.penulis.nama}. Dihapus sungguhan, bukan disembunyikan.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    final sebelum = _daftar;
    setState(() => _daftar = [...?_daftar?.where((x) => x.id != k.id)]);
    try {
      await ref.read(linimasaRepositoryProvider).hapusKomentar(k.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _daftar = sebelum);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final daftar = _daftar;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(daftar?.length);
      },
      child: Padding(
        // Kolom tulis ikut naik bersama keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: TourvellaColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Komentar · ${widget.post.judul}',
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: TourvellaColors.divider),
              Expanded(
                child: _galat != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _galat!,
                            textAlign: TextAlign.center,
                            style: text.bodySmall,
                          ),
                        ),
                      )
                    : daftar == null
                    ? const Center(child: CircularProgressIndicator())
                    : daftar.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada komentar. Jadi yang pertama.',
                          style: text.bodyMedium?.copyWith(
                            color: TourvellaColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _gulir,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: daftar.length,
                        itemBuilder: (_, i) => _BarisKomentar(
                          komentar: daftar[i],
                          onHapus: daftar[i].bolehHapus
                              ? () => _hapus(daftar[i])
                              : null,
                        ),
                      ),
              ),
              const Divider(height: 1, color: TourvellaColors.divider),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tulisan,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Tulis komentar…',
                            counterText: '',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _kirim(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Kirim komentar',
                        onPressed: _mengirim ? null : _kirim,
                        icon: _mengirim
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisKomentar extends StatelessWidget {
  const _BarisKomentar({required this.komentar, this.onHapus});

  final Komentar komentar;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FotoProfil(
            url: komentar.penulis.fotoUrl,
            nama: komentar.penulis.nama,
            ukuran: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: komentar.penulis.nama,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${_kapan(komentar.dibuat)}',
                        style: text.bodySmall?.copyWith(
                          color: TourvellaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  komentar.isi,
                  style: text.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          if (onHapus != null)
            IconButton(
              tooltip: 'Hapus komentar',
              visualDensity: VisualDensity.compact,
              onPressed: onHapus,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: TourvellaColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  static String _kapan(DateTime t) {
    final beda = DateTime.now().difference(t);
    if (beda.inMinutes < 1) return 'baru saja';
    if (beda.inMinutes < 60) return '${beda.inMinutes} mnt';
    if (beda.inHours < 24) return '${beda.inHours} jam';
    return '${beda.inDays} hr';
  }
}
