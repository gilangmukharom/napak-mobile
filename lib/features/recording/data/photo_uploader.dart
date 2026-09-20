import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Pengunggah foto singgahan.
///
/// Fotonya diunggah **langsung ke penyimpanan**, tidak lewat backend. Foto
/// dari kamera HP bisa beberapa megabyte; mengalirkannya lewat API berarti
/// tiap unggahan menahan satu proses server yang semestinya melayani orang
/// lain. Backend hanya menerbitkan tiket bertanda tangan dan memeriksa apakah
/// orangnya memang boleh mengisi perjalanan itu.
///
/// Yang akhirnya tersimpan di jejak cuma kunci objeknya, dan itu pun
/// terenkripsi lewat jalur yang sama dengan koordinat dan catatan.
class PhotoUploader {
  PhotoUploader(this._api);

  final ApiClient _api;

  /// Dio terpisah tanpa interceptor Napak.
  ///
  /// URL bertanda tangan sudah membawa izinnya sendiri di query string.
  /// Menempelkan header Authorization ke sana justru membuat sebagian
  /// penyedia S3 menolak permintaannya.
  final _polos = Dio();

  final _pemilih = ImagePicker();

  /// Foto dari kamera. Inilah jalur yang paling sering dipakai — orang
  /// berhenti, memotret, lanjut jalan.
  Future<XFile?> dariKamera() => _pemilih.pickImage(
    source: ImageSource.camera,
    // Dikecilkan di HP sebelum diunggah. Foto 12 MP dari kamera modern tidak
    // memberi apa-apa untuk kenangan seukuran layar, tapi menghabiskan kuota
    // orang di pinggir jalan dengan sinyal seadanya.
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 82,
  );

  Future<XFile?> dariGaleri() => _pemilih.pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 82,
  );

  /// Unggah satu foto, kembalikan kunci objeknya untuk disimpan di jejak.
  Future<String> unggah(
    String tripId,
    XFile berkas, {
    void Function(int terkirim, int total)? kemajuan,
  }) async {
    final ukuran = await berkas.length();
    final tipe = _tipeKonten(berkas);

    final tiket = await _api.post<Map<String, dynamic>>(
      '/trips/$tripId/media/upload-ticket',
      body: {'contentType': tipe, 'sizeBytes': ukuran},
    );

    final uploadUrl = tiket['uploadUrl'] as String;
    final objectKey = tiket['objectKey'] as String;

    try {
      await _polos.put<void>(
        uploadUrl,
        data: File(berkas.path).openRead(),
        options: Options(
          headers: {
            Headers.contentTypeHeader: tipe,
            Headers.contentLengthHeader: ukuran,
          },
        ),
        onSendProgress: kemajuan,
      );
    } on DioException catch (error) {
      throw NapakException(
        'Fotonya gagal terkirim. Coba lagi kalau sinyalnya sudah lebih baik.',
        statusCode: error.response?.statusCode,
      );
    }

    return objectKey;
  }

  /// Ditebak dari nama berkasnya. Kamera iOS menghasilkan HEIC, Android JPG.
  String _tipeKonten(XFile berkas) {
    final nama = berkas.path.toLowerCase();
    if (nama.endsWith('.png')) return 'image/png';
    if (nama.endsWith('.webp')) return 'image/webp';
    if (nama.endsWith('.heic') || nama.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => PhotoUploader(ref.watch(apiClientProvider)),
);
