import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../garasi/data/garasi_data.dart';

class PenulisPost {
  const PenulisPost({required this.id, required this.nama, this.fotoUrl});

  final String id;
  final String nama;
  final String? fotoUrl;
}

class MediaPost {
  const MediaPost({required this.url, required this.video});

  final String url;
  final bool video;
}

/// Satu postingan di linimasa: perjalanan yang dipajang dan sudah selesai.
class PostLinimasa {
  const PostLinimasa({
    required this.tripId,
    required this.judul,
    required this.selesai,
    required this.km,
    required this.penulis,
    required this.milikSendiri,
    required this.media,
    required this.previewPath,
    required this.salut,
    required this.sudahSalut,
    this.mulai,
    this.dari,
    this.ke,
    this.kendaraanNama,
    this.kendaraanJenis,
  });

  factory PostLinimasa.fromJson(Map<String, dynamic> j) {
    final penulis = j['penulis'] as Map<String, dynamic>;
    final kendaraan = j['kendaraan'] as Map<String, dynamic>?;
    return PostLinimasa(
      tripId: j['tripId'] as String,
      judul: j['judul'] as String,
      mulai: DateTime.tryParse(j['mulai'] as String? ?? '')?.toLocal(),
      selesai: DateTime.parse(j['selesai'] as String).toLocal(),
      km: (j['km'] as num?)?.toDouble() ?? 0,
      penulis: PenulisPost(
        id: penulis['id'] as String,
        nama: penulis['nama'] as String,
        fotoUrl: penulis['fotoUrl'] as String?,
      ),
      milikSendiri: j['milikSendiri'] as bool? ?? false,
      dari: j['dari'] as String?,
      ke: j['ke'] as String?,
      media: [
        for (final m in (j['media'] as List<dynamic>? ?? const []))
          MediaPost(
            url: (m as Map<String, dynamic>)['url'] as String,
            video: m['video'] as bool? ?? false,
          ),
      ],
      // GeoJSON: [lng, lat].
      previewPath: [
        for (final p in (j['previewPath'] as List<dynamic>? ?? const []))
          (
            lat: ((p as List<dynamic>)[1] as num).toDouble(),
            lng: (p[0] as num).toDouble(),
          ),
      ],
      kendaraanNama: kendaraan?['nama'] as String?,
      kendaraanJenis: kendaraan == null
          ? null
          : JenisKendaraan.dari(kendaraan['jenis'] as String?),
      salut: (j['salut'] as num?)?.toInt() ?? 0,
      sudahSalut: j['sudahSalut'] as bool? ?? false,
    );
  }

  final String tripId;
  final String judul;
  final DateTime? mulai;
  final DateTime selesai;
  final double km;
  final PenulisPost penulis;
  final bool milikSendiri;
  final String? dari;
  final String? ke;
  final List<MediaPost> media;
  final List<({double lat, double lng})> previewPath;
  final String? kendaraanNama;
  final JenisKendaraan? kendaraanJenis;
  final int salut;
  final bool sudahSalut;

  PostLinimasa denganSalut(int jumlah, bool sudah) => PostLinimasa(
    tripId: tripId,
    judul: judul,
    mulai: mulai,
    selesai: selesai,
    km: km,
    penulis: penulis,
    milikSendiri: milikSendiri,
    dari: dari,
    ke: ke,
    media: media,
    previewPath: previewPath,
    kendaraanNama: kendaraanNama,
    kendaraanJenis: kendaraanJenis,
    salut: jumlah,
    sudahSalut: sudah,
  );
}

class LinimasaRepository {
  LinimasaRepository(this._api);

  final ApiClient _api;

  Future<List<PostLinimasa>> baca({DateTime? sebelum}) async {
    final data = await _api.get<List<dynamic>>(
      '/linimasa',
      query: {
        if (sebelum != null) 'sebelum': sebelum.toUtc().toIso8601String(),
      },
    );
    return [
      for (final p in data) PostLinimasa.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<({int salut, bool sudah})> salut(
    String tripId, {
    required bool beri,
  }) async {
    final data = beri
        ? await _api.put<Map<String, dynamic>>('/linimasa/$tripId/salut')
        : await _api.delete<Map<String, dynamic>>('/linimasa/$tripId/salut');
    return (
      salut: (data['salut'] as num).toInt(),
      sudah: data['sudahSalut'] as bool? ?? false,
    );
  }
}

final linimasaRepositoryProvider = Provider<LinimasaRepository>(
  (ref) => LinimasaRepository(ref.watch(apiClientProvider)),
);

final linimasaProvider = FutureProvider.autoDispose<List<PostLinimasa>>(
  (ref) => ref.watch(linimasaRepositoryProvider).baca(),
);
