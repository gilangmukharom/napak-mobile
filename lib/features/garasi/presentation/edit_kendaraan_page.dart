import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/widgets/tourvella_pressable.dart';
import '../data/garasi_data.dart';

/// Menambah atau mengubah satu kendaraan di garasi.
///
/// Tidak ada kolom pelat nomor — dan kalau suatu hari ada yang memintanya,
/// jawabannya tetap tidak. Lihat catatan di `Kendaraan`.
class EditKendaraanPage extends ConsumerStatefulWidget {
  const EditKendaraanPage({this.awal, super.key});

  /// Kendaraan yang diubah; `null` untuk menambah yang baru.
  final Kendaraan? awal;

  @override
  ConsumerState<EditKendaraanPage> createState() => _EditKendaraanPageState();
}

class _EditKendaraanPageState extends ConsumerState<EditKendaraanPage> {
  late final _nama = TextEditingController(text: widget.awal?.nama);
  late final _merek = TextEditingController(text: widget.awal?.merekModel);
  late final _tahun = TextEditingController(
    text: widget.awal?.tahun?.toString(),
  );
  late final _cerita = TextEditingController(text: widget.awal?.cerita);
  late JenisKendaraan _jenis = widget.awal?.jenis ?? JenisKendaraan.motor;

  XFile? _fotoBaru;
  bool _buangFoto = false;
  bool _menyimpan = false;
  String? _galat;

  @override
  void dispose() {
    _nama.dispose();
    _merek.dispose();
    _tahun.dispose();
    _cerita.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    final kamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Potret sekarang'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (kamera == null) return;

    final berkas = await ref
        .read(garasiRepositoryProvider)
        .pilihFoto(kamera: kamera);
    if (berkas != null && mounted) {
      setState(() {
        _fotoBaru = berkas;
        _buangFoto = false;
      });
    }
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(
        () => _galat = 'Beri dia nama dulu — "Si Merah", "Kebo", apa saja.',
      );
      return;
    }
    final tahunTeks = _tahun.text.trim();
    final tahun = tahunTeks.isEmpty ? null : int.tryParse(tahunTeks);
    if (tahunTeks.isNotEmpty &&
        (tahun == null || tahun < 1900 || tahun > DateTime.now().year + 1)) {
      setState(() => _galat = 'Tahunnya sepertinya keliru.');
      return;
    }

    setState(() {
      _menyimpan = true;
      _galat = null;
    });

    try {
      final repo = ref.read(garasiRepositoryProvider);
      final kunci = _fotoBaru == null
          ? null
          : await repo.unggahFoto(_fotoBaru!);
      await repo.simpan(
        id: widget.awal?.id,
        nama: nama,
        jenis: _jenis,
        merekModel: _merek.text.trim(),
        tahun: tahun,
        cerita: _cerita.text.trim(),
        fotoKey: kunci,
        buangFoto: _buangFoto,
      );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (galat) {
      if (mounted) setState(() => _galat = galat.toString());
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fotoLama = _buangFoto ? null : widget.awal?.fotoUrl;

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      appBar: BilahEkspedisi(
        judul: widget.awal == null ? 'Kendaraan baru' : 'Ubah kendaraan',
        keterangan: 'Garasi',
        aksi: [
          TextButton(
            onPressed: _menyimpan ? null : _simpan,
            style: TextButton.styleFrom(
              foregroundColor: TourvellaColors.emberRedup,
            ),
            child: _menyimpan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          TourvellaPressable(
            skala: 0.98,
            onTap: _pilihFoto,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: TourvellaColors.malam,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_fotoBaru != null)
                      Image.file(File(_fotoBaru!.path), fit: BoxFit.cover)
                    else if (fotoLama != null)
                      Image.network(fotoLama, fit: BoxFit.cover)
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _jenis.ikon,
                            size: 48,
                            color: TourvellaColors.base.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 10),
                          const LabelKapital(
                            'Ketuk untuk memotret',
                            warna: TourvellaColors.emberRedup,
                          ),
                        ],
                      ),
                    if (_fotoBaru != null || fotoLama != null)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: TourvellaColors.malam.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          tooltip: 'Buang foto',
                          onPressed: () => setState(() {
                            _fotoBaru = null;
                            _buangFoto = true;
                          }),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: TourvellaColors.base,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tips: potret dari samping, pelat nomornya tidak perlu kelihatan.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),

          const LabelKapital('Jenis'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final j in JenisKendaraan.values)
                TourvellaPressable(
                  skala: 0.94,
                  onTap: () => setState(() => _jenis = j),
                  child: AnimatedContainer(
                    duration: TourvellaMotion.cepat,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _jenis == j
                          ? TourvellaColors.ember.withValues(alpha: 0.14)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _jenis == j
                            ? TourvellaColors.ember
                            : TourvellaColors.divider,
                        width: _jenis == j ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          j.ikon,
                          size: 18,
                          color: _jenis == j
                              ? TourvellaColors.ember
                              : TourvellaColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(j.label),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),

          const LabelKapital('Nama panggilannya'),
          const SizedBox(height: 8),
          TextField(
            controller: _nama,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Si Merah'),
          ),
          const SizedBox(height: 10),
          const LabelKapital('Merek & model'),
          const SizedBox(height: 8),
          TextField(
            controller: _merek,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Honda CB150R'),
          ),
          const SizedBox(height: 10),
          const LabelKapital('Tahun'),
          const SizedBox(height: 8),
          TextField(
            controller: _tahun,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(hintText: '2019'),
          ),
          const SizedBox(height: 22),
          const LabelKapital('Ceritanya'),
          const SizedBox(height: 8),
          TextField(
            controller: _cerita,
            maxLength: 300,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Dibeli bekas 2021, sudah dua kali mudik Pantura…',
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(
              _galat!,
              style: text.bodySmall?.copyWith(color: TourvellaColors.attention),
            ),
          ],
        ],
      ),
    );
  }
}
