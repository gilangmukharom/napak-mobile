import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../trips/data/trip_models.dart';
import '../presentation/penampil_media.dart';

enum Hubungan {
  diriSendiri('diri_sendiri'),
  teman('teman'),
  menungguDia('menunggu_dia'),
  menungguSaya('menunggu_saya'),
  belum('belum');

  const Hubungan(this.wire);
  final String wire;

  static Hubungan dari(String? w) =>
      values.firstWhere((h) => h.wire == w, orElse: () => Hubungan.belum);
}

class StatistikProfil {
  const StatistikProfil({
    required this.perjalanan,
    required this.km,
    required this.provinsi,
    required this.teman,
  });

  factory StatistikProfil.fromJson(Map<String, dynamic> j) => StatistikProfil(
    perjalanan: j['perjalanan'] as int? ?? 0,
    km: (j['km'] as num?)?.toDouble() ?? 0,
    provinsi: j['provinsi'] as int? ?? 0,
    teman: j['teman'] as int? ?? 0,
  );

  final int perjalanan;
  final double km;
  final int provinsi;
  final int teman;
}

class Profil {
  const Profil({
    required this.id,
    required this.nama,
    required this.hubungan,
    required this.terbuka,
    this.bio,
    this.fotoUrl,
    this.kodeTourvella,
    this.permintaanId,
    this.statistik,
  });

  factory Profil.fromJson(Map<String, dynamic> j) => Profil(
    id: j['id'] as String,
    nama: j['nama'] as String,
    bio: j['bio'] as String?,
    fotoUrl: j['fotoUrl'] as String?,
    kodeTourvella: j['kodeTourvella'] as String?,
    hubungan: Hubungan.dari(j['hubungan'] as String?),
    permintaanId: j['permintaanId'] as String?,
    terbuka: j['terbuka'] as bool? ?? false,
    statistik: j['statistik'] == null
        ? null
        : StatistikProfil.fromJson(j['statistik'] as Map<String, dynamic>),
  );

  final String id;
  final String nama;
  final String? bio;
  final String? fotoUrl;
  final String? kodeTourvella;
  final Hubungan hubungan;
  final String? permintaanId;
  final bool terbuka;
  final StatistikProfil? statistik;

  bool get diriSendiri => hubungan == Hubungan.diriSendiri;
}

class Dokumentasi {
  const Dokumentasi({
    required this.id,
    required this.tripId,
    required this.judulPerjalanan,
    required this.video,
    required this.url,
    required this.pada,
    required this.dipajang,
    this.posterUrl,
    this.catatan,
    this.tempat,
  });

  factory Dokumentasi.fromJson(Map<String, dynamic> j) => Dokumentasi(
    id: j['id'] as String,
    tripId: j['tripId'] as String,
    judulPerjalanan: j['judulPerjalanan'] as String,
    video: j['jenis'] == 'video',
    url: j['url'] as String,
    posterUrl: j['posterUrl'] as String?,
    catatan: j['catatan'] as String?,
    tempat: j['tempat'] as String?,
    pada: DateTime.parse(j['pada'] as String).toLocal(),
    dipajang: j['dipajang'] as bool? ?? true,
  );

  final String id;
  final String tripId;
  final String judulPerjalanan;
  final bool video;
  final String url;
  final String? posterUrl;
  final String? catatan;
  final String? tempat;
  final DateTime pada;
  final bool dipajang;

  MediaTampil get tampil => MediaTampil(
    id: id,
    url: url,
    video: video,
    posterUrl: posterUrl,
    judul: judulPerjalanan,
    catatan: catatan,
    tempat: tempat,
    pada: pada,
    tripId: tripId,
  );
}

class ProfilRepository {
  ProfilRepository(this._api);

  final ApiClient _api;
  final _polos = Dio();
  final _pemilih = ImagePicker();

  Future<Profil> saya() async =>
      Profil.fromJson(await _api.get<Map<String, dynamic>>('/profil/saya'));

  Future<Profil> lihat(String id) async =>
      Profil.fromJson(await _api.get<Map<String, dynamic>>('/profil/$id'));

  Future<List<Dokumentasi>> dokumentasi(String id, {DateTime? sebelum}) async {
    final data = await _api.get<List<dynamic>>(
      '/profil/$id/dokumentasi',
      query: {
        if (sebelum != null) 'sebelum': sebelum.toUtc().toIso8601String(),
      },
    );
    return [
      for (final d in data) Dokumentasi.fromJson(d as Map<String, dynamic>),
    ];
  }

  Future<List<Trip>> perjalanan(String id) async {
    final data = await _api.get<List<dynamic>>('/profil/$id/perjalanan');
    return [for (final t in data) Trip.fromJson(t as Map<String, dynamic>)];
  }

  Future<Profil> ubah({String? nama, String? bio}) async => Profil.fromJson(
    await _api.patch<Map<String, dynamic>>(
      '/profil/saya',
      body: {'nama': ?nama, 'bio': ?bio},
    ),
  );

  Future<XFile?> pilihFoto({required bool kamera}) => _pemilih.pickImage(
    source: kamera ? ImageSource.camera : ImageSource.gallery,
    // Foto profil tampil paling besar seukuran lingkaran di layar; 1024 px
    // sudah lebih dari cukup.
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.front,
  );

  Future<Profil> gantiFoto(XFile berkas) async {
    final nama = berkas.path.toLowerCase();
    final tipe = nama.endsWith('.png')
        ? 'image/png'
        : nama.endsWith('.webp')
        ? 'image/webp'
        : nama.endsWith('.heic') || nama.endsWith('.heif')
        ? 'image/heic'
        : 'image/jpeg';

    final tiket = await _api.post<Map<String, dynamic>>(
      '/profil/saya/foto/tiket',
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

    return Profil.fromJson(
      await _api.put<Map<String, dynamic>>(
        '/profil/saya/foto',
        body: {'objectKey': tiket['objectKey']},
      ),
    );
  }

  Future<Profil> hapusFoto() async => Profil.fromJson(
    await _api.delete<Map<String, dynamic>>('/profil/saya/foto'),
  );
}

final profilRepositoryProvider = Provider<ProfilRepository>(
  (ref) => ProfilRepository(ref.watch(apiClientProvider)),
);

/// Profil siapa pun, dikunci id. `saya` untuk diri sendiri.
final profilProvider = FutureProvider.autoDispose.family<Profil, String>((
  ref,
  id,
) {
  final repo = ref.watch(profilRepositoryProvider);
  return id == 'saya' ? repo.saya() : repo.lihat(id);
});

final dokumentasiProvider = FutureProvider.autoDispose
    .family<List<Dokumentasi>, String>(
      (ref, id) => ref.watch(profilRepositoryProvider).dokumentasi(id),
    );

final perjalananProfilProvider = FutureProvider.autoDispose
    .family<List<Trip>, String>(
      (ref, id) => ref.watch(profilRepositoryProvider).perjalanan(id),
    );
