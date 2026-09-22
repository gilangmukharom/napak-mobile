import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Satu tujuan yang bisa dipilih. Dari tabel kota Tourvella sendiri — tidak
/// ada nama tempat yang dikirim ke layanan geocoding pihak mana pun.
@immutable
class Tujuan {
  const Tujuan({
    required this.nama,
    required this.provinsi,
    required this.lat,
    required this.lng,
  });

  factory Tujuan.fromJson(Map<String, dynamic> j) => Tujuan(
    nama: j['nama'] as String,
    provinsi: j['provinsi'] as String? ?? '',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
  );

  /// Titik yang ditunjuk sendiri di peta, tanpa nama kota.
  const Tujuan.titik(this.lat, this.lng) : nama = 'Titik pilihan', provinsi = '';

  final String nama;
  final String provinsi;
  final double lat;
  final double lng;
}

/// Satu manuver: belok, bundaran, keluar tol, sampai.
@immutable
class LangkahRute {
  const LangkahRute({
    required this.jarakM,
    required this.durasiDetik,
    required this.jenis,
    required this.arah,
    required this.lat,
    required this.lng,
    this.jalan,
  });

  factory LangkahRute.fromJson(Map<String, dynamic> j) {
    final manuver = j['manuver'] as Map<String, dynamic>;
    final lokasi = j['lokasi'] as List<dynamic>;
    return LangkahRute(
      jarakM: (j['jarakM'] as num).toDouble(),
      durasiDetik: (j['durasiDetik'] as num).toDouble(),
      jenis: manuver['jenis'] as String,
      arah: manuver['arah'] as String,
      jalan: j['jalan'] as String?,
      // GeoJSON: [lng, lat]. Tertukar sedikit saja, panah navigasinya
      // menunjuk ke tengah Samudra Hindia.
      lng: (lokasi[0] as num).toDouble(),
      lat: (lokasi[1] as num).toDouble(),
    );
  }

  final double jarakM;
  final double durasiDetik;
  final String jenis;
  final String arah;
  final String? jalan;
  final double lat;
  final double lng;

  bool get sampai => jenis == 'sampai';
}

@immutable
class Rute {
  const Rute({
    required this.jarakM,
    required this.durasiDetik,
    required this.garis,
    required this.langkah,
    required this.ringkasan,
    required this.tujuan,
  });

  factory Rute.fromJson(Map<String, dynamic> j, Tujuan tujuan) => Rute(
    jarakM: (j['jarakM'] as num).toDouble(),
    durasiDetik: (j['durasiDetik'] as num).toDouble(),
    garis: [
      for (final t in (j['garis'] as List<dynamic>))
        (lat: ((t as List<dynamic>)[1] as num).toDouble(),
         lng: (t[0] as num).toDouble()),
    ],
    langkah: [
      for (final l in (j['langkah'] as List<dynamic>))
        LangkahRute.fromJson(l as Map<String, dynamic>),
    ],
    ringkasan: j['ringkasan'] as String? ?? '',
    tujuan: tujuan,
  );

  final double jarakM;
  final double durasiDetik;
  final List<({double lat, double lng})> garis;
  final List<LangkahRute> langkah;

  /// Kalimat pembuka yang dibacakan sekali saat berangkat.
  final String ringkasan;
  final Tujuan tujuan;
}

class NavigasiRepository {
  NavigasiRepository(this._api);

  final ApiClient _api;

  Future<List<Tujuan>> cari(String kata) async {
    final data = await _api.get<List<dynamic>>(
      '/rute/cari',
      query: {'q': kata},
    );
    return [for (final t in data) Tujuan.fromJson(t as Map<String, dynamic>)];
  }

  /// Koordinat lewat badan POST, bukan query string — rencana perjalanan
  /// seseorang tidak perlu tercatat di log akses.
  Future<Rute> hitung({
    required double dariLat,
    required double dariLng,
    required Tujuan ke,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/rute',
      body: {
        'dari': {'lat': dariLat, 'lng': dariLng},
        'ke': {'lat': ke.lat, 'lng': ke.lng},
        'tujuan': ke.nama,
      },
    );
    return Rute.fromJson(data, ke);
  }
}

final navigasiRepositoryProvider = Provider<NavigasiRepository>(
  (ref) => NavigasiRepository(ref.watch(apiClientProvider)),
);
