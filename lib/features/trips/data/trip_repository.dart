import '../../../core/network/api_client.dart';
import 'trip_models.dart';

class SyncResult {
  const SyncResult({
    required this.accepted,
    required this.skipped,
    required this.distanceKm,
  });

  final int accepted;
  final int skipped;
  final double distanceKm;
}

/// Satu titik siap kirim, sudah dalam bentuk yang dimengerti backend.
class OutgoingPoint {
  const OutgoingPoint({
    required this.clientId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.alt,
    this.accuracy,
    this.speedMps,
    this.transportMode = 'tidak_diketahui',
    this.note,
    this.photoUrl,
  });

  final String clientId;
  final double lat;
  final double lng;
  final DateTime recordedAt;
  final double? alt;
  final double? accuracy;
  final double? speedMps;
  final String transportMode;
  final String? note;
  final String? photoUrl;

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'lat': lat,
    'lng': lng,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (alt != null) 'alt': alt,
    if (accuracy != null) 'accuracy': accuracy,
    if (speedMps != null) 'speedMps': speedMps,
    'transportMode': transportMode,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
  };
}

class TripRepository {
  TripRepository(this._api);

  final ApiClient _api;

  Future<List<Trip>> list() async {
    final data = await _api.get<List<dynamic>>('/trips');
    return data
        .map((json) => Trip.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Perjalanan di tanggal yang sama, tahun-tahun lalu.
  Future<List<Trip>> kenanganHariIni() async {
    final data = await _api.get<List<dynamic>>('/trips/kenangan');
    return data
        .map((json) => Trip.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> detail(String tripId) async {
    final data = await _api.get<Map<String, dynamic>>('/trips/$tripId');
    return Trip.fromJson(data);
  }

  Future<Trip> create({
    required String title,
    TripMode mode = TripMode.solo,
    String? retraceOf,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/trips',
      body: {
        'title': title,
        'mode': mode.wire,
        'retraceOf': ?retraceOf,
      },
    );
    return Trip.fromJson(data);
  }

  Future<List<TripPoint>> points(String tripId) async {
    final data = await _api.get<List<dynamic>>('/trips/$tripId/points');
    return data
        .map((json) => TripPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Kirim satu rombongan jejak. Aman diulang: backend mengenali clientId
  /// yang sudah pernah masuk dan melewatkannya.
  Future<SyncResult> pushPoints(
    String tripId,
    List<OutgoingPoint> points,
  ) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/trips/$tripId/points',
      body: {'points': points.map((p) => p.toJson()).toList()},
    );
    return SyncResult(
      accepted: data['accepted'] as int? ?? 0,
      skipped: data['skipped'] as int? ?? 0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<Trip> finish(String tripId) async {
    final data = await _api.post<Map<String, dynamic>>('/trips/$tripId/finish');
    return Trip.fromJson(data);
  }

  Future<Trip> setVisibility(String tripId, TripVisibility visibility) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '/trips/$tripId',
      body: {'visibility': visibility.wire},
    );
    return Trip.fromJson(data);
  }

  Future<Trip> setDiProfil(String tripId, {required bool pajang}) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '/trips/$tripId',
      body: {'diProfil': pajang},
    );
    return Trip.fromJson(data);
  }

  Future<Trip> rename(String tripId, String title) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '/trips/$tripId',
      body: {'title': title},
    );
    return Trip.fromJson(data);
  }

  /// Permanen. Judulnya harus diketik ulang — backend menolak kalau tidak sama.
  Future<String> deletePermanently(String tripId, String confirmTitle) async {
    final data = await _api.delete<Map<String, dynamic>>(
      '/trips/$tripId',
      body: {'confirmTitle': confirmTitle},
    );
    return data['message'] as String? ?? 'Perjalanan itu sudah dihapus.';
  }

  Future<List<TripMember>> members(String tripId) async {
    final data = await _api.get<List<dynamic>>('/trips/$tripId/members');
    return data
        .map((json) => TripMember.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<TripMember> joinBySlug(String slug) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/trips/join',
      body: {'slug': slug},
    );
    return TripMember.fromJson(data);
  }

  Future<bool> setLiveLocation(String tripId, {required bool enabled}) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/trips/$tripId/members/me/live-location',
      body: {'enabled': enabled},
    );
    return data['liveLocationEnabled'] as bool? ?? false;
  }

  Future<Recap> recap(int year) async {
    final data = await _api.get<Map<String, dynamic>>('/recap/$year');
    return Recap.fromJson(data);
  }

  Future<Recap> refreshRecap(int year) async {
    final data = await _api.post<Map<String, dynamic>>('/recap/$year/refresh');
    return Recap.fromJson(data);
  }

  // --- Video animasi rute ---

  /// Titipkan permintaan render. Pengerjaannya di latar belakang server.
  Future<RenderJob> mintaRender(
    String tripId, {
    FormatRender format = FormatRender.tegak,
    TemplateRender template = TemplateRender.perjalanan,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/trips/$tripId/render',
      body: {'format': format.wire, 'template': template.wire},
    );
    return RenderJob.fromJson(data);
  }

  Future<RenderJob> statusRender(String renderId) async {
    final data = await _api.get<Map<String, dynamic>>('/renders/$renderId');
    return RenderJob.fromJson(data);
  }

  Future<List<RenderJob>> daftarRender(String tripId) async {
    final data = await _api.get<List<dynamic>>('/trips/$tripId/renders');
    return data
        .map((json) => RenderJob.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Unduh perjalanan sebagai GPX.
  ///
  /// Pasangan jujur dari penghapusan permanen: kalau jejak ini milikmu, kamu
  /// harus bisa membawanya pergi. GPX dibaca hampir semua perkakas peta.
  Future<void> unduhGpx(String tripId, String tujuan) {
    return _api.unduhKeBerkas('/trips/$tripId/gpx', tujuan);
  }

  /// Unduh videonya ke berkas lokal supaya bisa dibagikan dari HP.
  Future<void> unduhVideo(
    String renderId,
    String tujuan, {
    void Function(int terkirim, int total)? kemajuan,
  }) {
    return _api.unduhKeBerkas(
      '/renders/$renderId/file',
      tujuan,
      kemajuan: kemajuan,
    );
  }
}
