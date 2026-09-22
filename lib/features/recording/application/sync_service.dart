import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/tourvella_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../trips/data/trip_repository.dart';
import '../data/local_database.dart';

/// Menyusulkan jejak yang sempat tertinggal saat sinyal hilang.
///
/// Titik selalu masuk ke database lokal dulu, baru dicoba dikirim. Urutannya
/// sengaja begitu: kalau aplikasi mati atau sinyalnya putus di tengah jalan,
/// yang sudah direkam tetap ada. Tidak ada jejak yang hilang hanya karena
/// pengirimannya gagal.
class SyncService {
  SyncService(this._db, this._trips);

  final TourvellaLocalDatabase _db;
  final TripRepository _trips;

  bool _running = false;

  /// Simpan satu jejak ke antrean lokal.
  Future<void> enqueue({
    required String tripId,
    required String clientId,
    required double lat,
    required double lng,
    required DateTime recordedAt,
    double? alt,
    double? accuracy,
    double? speedMps,
    String transportMode = 'tidak_diketahui',
    String? note,
    String? photoUrl,
  }) {
    return _db.enqueue(
      PendingPointsCompanion.insert(
        clientId: clientId,
        tripId: tripId,
        lat: lat,
        lng: lng,
        recordedAt: recordedAt,
        alt: Value(alt),
        accuracy: Value(accuracy),
        speedMps: Value(speedMps),
        transportMode: Value(transportMode),
        note: Value(note),
        photoUrl: Value(photoUrl),
      ),
    );
  }

  /// Coba kirim antrean yang menumpuk.
  ///
  /// Aman dipanggil sesering apa pun — kalau satu putaran sedang berjalan,
  /// panggilan berikutnya diabaikan, bukan menumpuk jadi antrean baru.
  /// Mengembalikan jumlah titik yang berhasil sampai di server.
  Future<int> flush() async {
    if (_running) return 0;
    _running = true;

    var totalSynced = 0;
    try {
      while (true) {
        final batch = await _db.nextBatch(limit: TourvellaConfig.syncBatchSize);
        if (batch.isEmpty) break;

        // Dikelompokkan per perjalanan karena endpointnya memang per perjalanan.
        final byTrip = <String, List<PendingPoint>>{};
        for (final point in batch) {
          byTrip.putIfAbsent(point.tripId, () => []).add(point);
        }

        var progressed = false;
        for (final entry in byTrip.entries) {
          final ids = entry.value.map((p) => p.clientId).toList();
          try {
            await _trips.pushPoints(
              entry.key,
              entry.value.map(_toOutgoing).toList(),
            );
            // Sudah aman di server, boleh dilepas dari perangkat.
            await _db.clearSynced(ids);
            totalSynced += ids.length;
            progressed = true;
          } on TourvellaException catch (error) {
            if (error.statusCode == 404) {
              // Perjalanannya sudah tidak ada — mungkin dihapus dari perangkat
              // lain. Jejak yang menuju ke sana tidak ada gunanya lagi.
              await _db.dropTrip(entry.key);
              progressed = true;
            } else {
              await _db.markFailed(ids);
            }
          }
        }

        // Tidak ada kemajuan sama sekali berarti jaringannya memang sedang
        // tidak bisa. Berhenti, nanti dicoba lagi.
        if (!progressed) break;
      }
    } finally {
      _running = false;
    }

    return totalSynced;
  }

  OutgoingPoint _toOutgoing(PendingPoint p) => OutgoingPoint(
    clientId: p.clientId,
    lat: p.lat,
    lng: p.lng,
    recordedAt: p.recordedAt,
    alt: p.alt,
    accuracy: p.accuracy,
    speedMps: p.speedMps,
    transportMode: p.transportMode,
    note: p.note,
    photoUrl: p.photoUrl,
  );
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(localDatabaseProvider),
    ref.watch(tripRepositoryProvider),
  ),
);
