import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

enum JenisKendaraan {
  motor('motor', 'Motor', Icons.two_wheeler_rounded),
  mobil('mobil', 'Mobil', Icons.directions_car_rounded),
  sepeda('sepeda', 'Sepeda', Icons.pedal_bike_rounded),
  lainnya('lainnya', 'Lainnya', Icons.airport_shuttle_rounded);

  const JenisKendaraan(this.wire, this.label, this.ikon);
  final String wire;
  final String label;
  final IconData ikon;

  static JenisKendaraan dari(String? w) => values.firstWhere(
    (j) => j.wire == w,
    orElse: () => JenisKendaraan.lainnya,
  );
}

/// Satu kendaraan di garasi.
///
/// Tidak ada pelat nomor, dan memang tidak akan ada: pelat adalah satu-satunya
/// hal di foto kendaraan yang bisa dicocokkan dengan kamera jalan.
class Kendaraan {
  const Kendaraan({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.km,
    required this.perjalanan,
    required this.milikSendiri,
    this.merekModel,
    this.tahun,
    this.cerita,
    this.fotoUrl,
  });

  factory Kendaraan.fromJson(Map<String, dynamic> j) => Kendaraan(
    id: j['id'] as String,
    nama: j['nama'] as String,
    jenis: JenisKendaraan.dari(j['jenis'] as String?),
    merekModel: j['merekModel'] as String?,
    tahun: (j['tahun'] as num?)?.toInt(),
    cerita: j['cerita'] as String?,
    fotoUrl: j['fotoUrl'] as String?,
    km: (j['km'] as num?)?.toDouble() ?? 0,
    perjalanan: (j['perjalanan'] as num?)?.toInt() ?? 0,
    milikSendiri: j['milikSendiri'] as bool? ?? false,
  );

  final String id;
  final String nama;
  final JenisKendaraan jenis;
  final String? merekModel;
  final int? tahun;
  final String? cerita;
  final String? fotoUrl;
  final double km;
  final int perjalanan;
  final bool milikSendiri;
}

class GarasiRepository {
  GarasiRepository(this._api);

  final ApiClient _api;
  final _polos = Dio();
  final _pemilih = ImagePicker();

  Future<List<Kendaraan>> daftar({String? userId}) async {
    final data = await _api.get<List<dynamic>>(
      userId == null ? '/garasi/saya' : '/garasi/orang/$userId',
    );
    return [
      for (final k in data) Kendaraan.fromJson(k as Map<String, dynamic>),
    ];
  }

  Future<XFile?> pilihFoto({required bool kamera}) => _pemilih.pickImage(
    source: kamera ? ImageSource.camera : ImageSource.gallery,
    // Foto garasi tampil selebar kartu di kisi dua kolom; 1600 px cukup
    // untuk dibuka layar penuh tanpa membengkakkan unggahan.
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );

  /// Mengunggah foto langsung ke penyimpanan, lalu mengembalikan kuncinya.
  Future<String> unggahFoto(XFile berkas) async {
    final nama = berkas.path.toLowerCase();
    final tipe = nama.endsWith('.png')
        ? 'image/png'
        : nama.endsWith('.webp')
        ? 'image/webp'
        : nama.endsWith('.heic') || nama.endsWith('.heif')
        ? 'image/heic'
        : 'image/jpeg';

    final tiket = await _api.post<Map<String, dynamic>>(
      '/garasi/foto/tiket',
      body: {'contentType': tipe},
    );

    try {
      await _polos.put<void>(
        tiket['uploadUrl'] as String,
        data: File(berkas.path).openRead(),
        options: Options(
          headers: {
            Headers.contentTypeHeader: tipe,
            Headers.contentLengthHeader: await berkas.length(),
          },
        ),
      );
    } on DioException {
      throw TourvellaException(
        'Fotonya gagal terkirim. Coba lagi sebentar lagi.',
      );
    }
    return tiket['objectKey'] as String;
  }

  Future<Kendaraan> simpan({
    String? id,
    required String nama,
    required JenisKendaraan jenis,
    String? merekModel,
    int? tahun,
    String? cerita,
    String? fotoKey,
    bool buangFoto = false,
  }) async {
    final badan = <String, dynamic>{
      'nama': nama,
      'jenis': jenis.wire,
      'merekModel': merekModel,
      'tahun': tahun,
      'cerita': cerita,
      // Tidak dikirim = foto dibiarkan; `null` = foto dibuang.
      if (fotoKey != null || buangFoto) 'fotoKey': fotoKey,
    };
    final data = id == null
        ? await _api.post<Map<String, dynamic>>('/garasi', body: badan)
        : await _api.patch<Map<String, dynamic>>('/garasi/$id', body: badan);
    return Kendaraan.fromJson(data);
  }

  Future<void> hapus(String id) =>
      _api.delete<Map<String, dynamic>>('/garasi/$id');
}

final garasiRepositoryProvider = Provider<GarasiRepository>(
  (ref) => GarasiRepository(ref.watch(apiClientProvider)),
);

/// Garasi seseorang. `saya` untuk garasi sendiri.
final garasiProvider = FutureProvider.autoDispose
    .family<List<Kendaraan>, String>(
      (ref, id) => ref
          .watch(garasiRepositoryProvider)
          .daftar(userId: id == 'saya' ? null : id),
    );
