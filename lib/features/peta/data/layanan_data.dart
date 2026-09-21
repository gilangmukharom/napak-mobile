import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

enum JenisLayanan {
  spbu('spbu', 'SPBU'),
  bengkel('bengkel', 'Bengkel'),
  tambalBan('tambal_ban', 'Tambal ban');

  const JenisLayanan(this.wire, this.label);
  final String wire;
  final String label;

  static JenisLayanan dari(String w) =>
      values.firstWhere((j) => j.wire == w, orElse: () => JenisLayanan.bengkel);
}

class Layanan {
  const Layanan({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.lat,
    required this.lng,
    required this.untukMotor,
    required this.untukMobil,
    this.merek,
    this.jamBuka,
    this.buka24Jam = false,
    this.telepon,
    this.jarakM,
    this.arah,
  });

  factory Layanan.fromJson(Map<String, dynamic> j) => Layanan(
    id: j['id'] as String,
    jenis: JenisLayanan.dari(j['jenis'] as String),
    nama: j['nama'] as String,
    merek: j['merek'] as String?,
    jamBuka: j['jamBuka'] as String?,
    buka24Jam: j['buka24Jam'] as bool? ?? false,
    telepon: j['telepon'] as String?,
    untukMotor: j['untukMotor'] as bool? ?? true,
    untukMobil: j['untukMobil'] as bool? ?? true,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    jarakM: (j['jarakM'] as num?)?.toDouble(),
    arah: (j['arah'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'jenis': jenis.wire,
    'nama': nama,
    'merek': merek,
    'jamBuka': jamBuka,
    'buka24Jam': buka24Jam,
    'telepon': telepon,
    'untukMotor': untukMotor,
    'untukMobil': untukMobil,
    'lat': lat,
    'lng': lng,
  };

  final String id;
  final JenisLayanan jenis;
  final String nama;
  final String? merek;
  final String? jamBuka;
  final bool buka24Jam;
  final String? telepon;
  final bool untukMotor;
  final bool untukMobil;
  final double lat;
  final double lng;

  /// Jarak garis lurus, meter.
  final double? jarakM;

  /// Arah dari posisi pencari, derajat dari utara.
  final double? arah;

  Layanan dariPosisi(double lat0, double lng0) => Layanan(
    id: id,
    jenis: jenis,
    nama: nama,
    merek: merek,
    jamBuka: jamBuka,
    buka24Jam: buka24Jam,
    telepon: telepon,
    untukMotor: untukMotor,
    untukMobil: untukMobil,
    lat: lat,
    lng: lng,
    jarakM: jarakMeter(lat0, lng0, lat, lng),
    arah: arahDerajat(lat0, lng0, lat, lng),
  );
}

/// Hasil pencarian beserta dari mana datangnya.
class HasilLayanan {
  const HasilLayanan({required this.daftar, required this.dariOffline});

  final List<Layanan> daftar;

  /// true kalau dijawab dari data yang sudah diunduh bersama peta offline —
  /// ditampilkan ke pengguna, supaya jelas datanya tidak sesegar yang online.
  final bool dariOffline;
}

double jarakMeter(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double arahDerajat(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final y = math.sin(rad(lng2 - lng1)) * math.cos(rad(lat2));
  final x =
      math.cos(rad(lat1)) * math.sin(rad(lat2)) -
      math.sin(rad(lat1)) * math.cos(rad(lat2)) * math.cos(rad(lng2 - lng1));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// "timur laut", "selatan" — cara orang menunjuk arah di pinggir jalan.
String namaArah(double derajat) {
  const nama = [
    'utara',
    'timur laut',
    'timur',
    'tenggara',
    'selatan',
    'barat daya',
    'barat',
    'barat laut',
  ];
  return nama[((derajat + 22.5) % 360 ~/ 45)];
}

String teksJarak(double meter) {
  if (meter < 1000) return '${(meter / 10).round() * 10} m';
  final km = meter / 1000;
  return km >= 10
      ? '${km.round()} km'
      : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// SPBU, bengkel, tambal ban di sekitar — online dulu, jatuh ke data offline.
class LayananRepository {
  LayananRepository(this._api);

  final ApiClient _api;

  Future<Directory> _folder() async {
    final dok = await getApplicationDocumentsDirectory();
    final f = Directory('${dok.path}/layanan_offline');
    if (!f.existsSync()) await f.create(recursive: true);
    return f;
  }

  Future<HasilLayanan> terdekat({
    required double lat,
    required double lng,
    JenisLayanan? jenis,
    String? kendaraan,
  }) async {
    try {
      final data = await _api.post<List<dynamic>>(
        '/layanan/terdekat',
        // Posisi dikasarkan di HP juga, sebelum dikirim — server
        // mengasarkannya lagi, tapi yang tidak pernah dikirim tidak bisa
        // bocor di tengah jalan.
        body: {
          'lat': (lat * 1000).round() / 1000,
          'lng': (lng * 1000).round() / 1000,
          'jenis': ?jenis?.wire,
          'kendaraan': ?kendaraan,
        },
      );
      return HasilLayanan(
        daftar: [
          for (final d in data) Layanan.fromJson(d as Map<String, dynamic>),
        ],
        dariOffline: false,
      );
    } catch (_) {
      // Di jalan tanpa sinyal: hitung dari data yang ikut diunduh bersama
      // peta offline. Tidak ada yang dikirim ke mana pun.
      final lokal = await _bacaSemuaLokal();
      if (lokal.isEmpty) rethrow;

      final hasil =
          lokal
              .where((l) => jenis == null || l.jenis == jenis)
              .where(
                (l) =>
                    kendaraan == null ||
                    (kendaraan == 'motor' ? l.untukMotor : l.untukMobil),
              )
              .map((l) => l.dariPosisi(lat, lng))
              .where((l) => l.jarakM! <= 60000)
              .toList()
            ..sort((a, b) => a.jarakM!.compareTo(b.jarakM!));

      return HasilLayanan(daftar: hasil.take(20).toList(), dariOffline: true);
    }
  }

  /// Diunduh bersama satu wilayah peta offline.
  Future<int> simpanWilayah(
    int idWilayah,
    ({double s, double w, double n, double e}) kotak,
  ) async {
    final data = await _api.get<List<dynamic>>(
      '/layanan/wilayah',
      query: {
        's': kotak.s.toString(),
        'w': kotak.w.toString(),
        'n': kotak.n.toString(),
        'e': kotak.e.toString(),
      },
    );
    final f = await _folder();
    await File('${f.path}/$idWilayah.json').writeAsString(jsonEncode(data));
    return data.length;
  }

  Future<void> hapusWilayah(int idWilayah) async {
    final f = File('${(await _folder()).path}/$idWilayah.json');
    if (f.existsSync()) await f.delete();
  }

  Future<int> jumlahLokal(int idWilayah) async {
    final f = File('${(await _folder()).path}/$idWilayah.json');
    if (!f.existsSync()) return 0;
    return (jsonDecode(await f.readAsString()) as List).length;
  }

  Future<List<Layanan>> _bacaSemuaLokal() async {
    final f = await _folder();
    final hasil = <String, Layanan>{};
    for (final berkas in f.listSync().whereType<File>()) {
      try {
        final isi = jsonDecode(await berkas.readAsString()) as List;
        for (final d in isi) {
          final l = Layanan.fromJson(d as Map<String, dynamic>);
          // Wilayah yang bertumpuk tidak menggandakan satu SPBU.
          hasil[l.id] = l;
        }
      } catch (_) {
        // Berkas rusak dilewati; sisanya tetap berguna.
      }
    }
    return hasil.values.toList();
  }
}

final layananRepositoryProvider = Provider<LayananRepository>(
  (ref) => LayananRepository(ref.watch(apiClientProvider)),
);
