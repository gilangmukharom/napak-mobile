import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/tourvella_ekspedisi.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';
import '../data/profil_data.dart';
import 'profil_page.dart';

class EditProfilPage extends ConsumerStatefulWidget {
  const EditProfilPage({super.key});

  @override
  ConsumerState<EditProfilPage> createState() => _EditProfilPageState();
}

class _EditProfilPageState extends ConsumerState<EditProfilPage> {
  final _nama = TextEditingController();
  final _bio = TextEditingController();
  bool _terisi = false;
  bool _menyimpan = false;
  bool _mengunggah = false;

  /// Foto baru yang dipilih tapi belum selesai terunggah — ditampilkan
  /// langsung supaya tidak terasa menunggu.
  XFile? _fotoBaru;

  @override
  void dispose() {
    _nama.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _gantiFoto() async {
    final sumber = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TourvellaColors.base,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(context, 'kamera'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, 'galeri'),
            ),
            if (ref.read(profilProvider('saya')).value?.fotoUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: TourvellaColors.attention,
                ),
                title: const Text('Hapus foto'),
                onTap: () => Navigator.pop(context, 'hapus'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (sumber == null) return;

    final repo = ref.read(profilRepositoryProvider);
    try {
      if (sumber == 'hapus') {
        await repo.hapusFoto();
        setState(() => _fotoBaru = null);
      } else {
        final berkas = await repo.pilihFoto(kamera: sumber == 'kamera');
        if (berkas == null) return;
        setState(() {
          _fotoBaru = berkas;
          _mengunggah = true;
        });
        await repo.gantiFoto(berkas);
        HapticFeedback.mediumImpact();
      }
      ref.invalidate(profilProvider('saya'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _fotoBaru = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _mengunggah = false);
    }
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) return;
    setState(() => _menyimpan = true);
    try {
      await ref
          .read(profilRepositoryProvider)
          .ubah(nama: nama, bio: _bio.text.trim());
      // Nama sapaan di beranda juga ikut berganti.
      await ref.read(authRepositoryProvider).simpanNama(nama);
      ref
        ..invalidate(profilProvider('saya'))
        ..invalidate(savedNameProvider);
      HapticFeedback.mediumImpact();
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider('saya'));
    final text = Theme.of(context).textTheme;

    final p = profil.value;
    if (p != null && !_terisi) {
      _nama.text = p.nama;
      _bio.text = p.bio ?? '';
      _terisi = true;
    }

    return Scaffold(
      backgroundColor: TourvellaColors.base,
      appBar: BilahEkspedisi(
        judul: 'Edit profil',
        keterangan: 'Yang dilihat teman',
        aksi: [
          TextButton(
            onPressed: _menyimpan || p == null ? null : _simpan,
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
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _mengunggah ? null : _gantiFoto,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _fotoBaru != null
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                child: ClipOval(
                                  child: Image.file(
                                    File(_fotoBaru!.path),
                                    width: 104,
                                    height: 104,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : FotoProfil(
                                nama: p.nama,
                                url: p.fotoUrl,
                                ukuran: 104,
                                cincin: true,
                              ),
                        if (_mengunggah)
                          const SizedBox(
                            width: 116,
                            height: 116,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: TourvellaColors.deepAccent,
                            ),
                          ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: TourvellaColors.deepAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TourvellaColors.base,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: TourvellaColors.textOnDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().scaleXY(
                  begin: 0.85,
                  curve: TourvellaMotion.memantul,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _mengunggah ? null : _gantiFoto,
                    child: const Text('Ganti foto profil'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Nama', style: text.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _nama,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(counterText: ''),
                ),
                const SizedBox(height: 18),
                Text('Bio', style: text.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _bio,
                  maxLength: 160,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Motor tua, rute baru. Mudik tiap Lebaran.',
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TourvellaColors.softSky.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: TourvellaColors.deepAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nama, foto, dan bio terlihat oleh siapa pun yang '
                          'punya kode Tourvella-mu. Perjalananmu tetap tertutup — '
                          'teman cuma melihat yang kamu pajang di profil.',
                          style: text.bodySmall?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
