import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

/// Jejak yang sudah direkam tapi belum sempat dikirim.
///
/// Inilah yang membuat Tourvella tetap bisa dipakai di jalur Sumatra yang
/// sinyalnya putus-putus, atau di kapal penyeberangan. Perjalanan tidak
/// berhenti hanya karena sinyalnya berhenti.
class PendingPoints extends Table {
  /// Dibuat di perangkat saat titiknya direkam. Server memakainya untuk
  /// mengenali kiriman ulang, jadi sinkron dua kali tidak menggandakan jejak.
  TextColumn get clientId => text()();

  TextColumn get tripId => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get alt => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get speedMps => real().nullable()();

  TextColumn get transportMode =>
      text().withDefault(const Constant('tidak_diketahui'))();

  TextColumn get note => text().nullable()();
  TextColumn get photoUrl => text().nullable()();

  /// Berapa kali pengiriman titik ini gagal. Dipakai untuk menahan diri
  /// mencoba terus-menerus saat ada yang benar-benar salah.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DriftDatabase(tables: [PendingPoints])
class TourvellaLocalDatabase extends _$TourvellaLocalDatabase {
  TourvellaLocalDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tourvella_local'));

  @override
  int get schemaVersion => 1;

  Future<void> enqueue(PendingPointsCompanion point) =>
      into(pendingPoints).insert(point, mode: InsertMode.insertOrReplace);

  Future<void> enqueueAll(List<PendingPointsCompanion> points) => batch(
    (b) => b.insertAll(pendingPoints, points, mode: InsertMode.insertOrReplace),
  );

  /// Antrean tertua dulu — urutan jejak adalah urutan ceritanya.
  Future<List<PendingPoint>> pendingFor(String tripId, {int limit = 200}) =>
      (select(pendingPoints)
            ..where((p) => p.tripId.equals(tripId))
            ..orderBy([(p) => OrderingTerm.asc(p.recordedAt)])
            ..limit(limit))
          .get();

  Future<List<PendingPoint>> nextBatch({int limit = 200}) =>
      (select(pendingPoints)
            ..where((p) => p.attempts.isSmallerThanValue(5))
            ..orderBy([(p) => OrderingTerm.asc(p.recordedAt)])
            ..limit(limit))
          .get();

  Future<int> countFor(String tripId) async {
    final query = selectOnly(pendingPoints)
      ..addColumns([pendingPoints.clientId.count()])
      ..where(pendingPoints.tripId.equals(tripId));
    final row = await query.getSingle();
    return row.read(pendingPoints.clientId.count()) ?? 0;
  }

  /// Menonton jumlah jejak yang belum terkirim, supaya UI bisa memberi tahu
  /// dengan tenang tanpa harus bertanya berulang kali.
  Stream<int> watchPendingCount() {
    final query = selectOnly(pendingPoints)
      ..addColumns([pendingPoints.clientId.count()]);
    return query.watchSingle().map(
      (row) => row.read(pendingPoints.clientId.count()) ?? 0,
    );
  }

  /// Dipanggil setelah server memastikan titik-titik ini sudah masuk.
  Future<void> clearSynced(List<String> clientIds) =>
      (delete(pendingPoints)..where((p) => p.clientId.isIn(clientIds))).go();

  Future<void> markFailed(List<String> clientIds) =>
      (update(pendingPoints)..where((p) => p.clientId.isIn(clientIds))).write(
        PendingPointsCompanion.custom(
          attempts: pendingPoints.attempts + const Constant(1),
        ),
      );

  /// Ikut terhapus saat perjalanannya dihapus permanen — tidak ada sisa di HP.
  Future<void> dropTrip(String tripId) =>
      (delete(pendingPoints)..where((p) => p.tripId.equals(tripId))).go();

  /// Dipanggil saat keluar akun.
  Future<void> wipe() => delete(pendingPoints).go();
}
