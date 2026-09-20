import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/napak_config.dart';
import '../../../core/providers.dart';
import '../../trips/data/trip_models.dart';
import '../data/photo_uploader.dart';
import 'napak_tilas.dart';
import 'sync_service.dart';

@immutable
class RecordingState {
  const RecordingState({
    this.tripId,
    this.title,
    this.recordedCount = 0,
    this.latest,
    this.jejak = const [],
    this.jarakM = 0,
    this.jejakLama = const [],
    this.menapakTilas,
    this.mengunggahFoto = false,
    this.starting = false,
    this.izinDitolak = false,
    this.message,
  });

  /// Perjalanan yang sedang direkam. null berarti tidak sedang merekam.
  final String? tripId;
  final String? title;

  /// Berapa jejak yang sudah terekam sesi ini, terkirim maupun belum.
  final int recordedCount;

  /// Posisi terakhir yang diterima, untuk menggeser peta tanpa menggambar ulang.
  final ({double lat, double lng, DateTime at})? latest;

  /// Rute sesi ini, di memori saja.
  ///
  /// Dipakai layar perekaman untuk menggambar garis rutenya seketika. Tidak
  /// bisa mengandalkan database lokal: begitu sebuah titik berhasil terkirim,
  /// ia dihapus dari antrean — antrean itu daftar yang belum sampai, bukan
  /// catatan perjalanan. Dan tidak bisa mengandalkan server juga, karena
  /// justru saat sinyal hilang layar ini harus tetap menggambar.
  final List<({double lat, double lng})> jejak;

  /// Jarak yang sudah ditempuh sesi ini, meter.
  ///
  /// Dihitung di HP, bukan ditanyakan ke server. Perbandingan napak tilas
  /// harus tetap jalan di jalur yang sinyalnya putus — justru di sanalah
  /// perjalanan panjang terjadi.
  final double jarakM;

  /// Perjalanan lama yang sedang ditapak-tilasi, sudah disiapkan.
  final List<JejakLama> jejakLama;

  /// Judul dan tanggal perjalanan lama itu.
  final RingkasTrip? menapakTilas;

  /// Sedang mengirim foto singgahan. Unggahannya bisa lama di sinyal buruk,
  /// jadi layarnya perlu bisa mengatakan itu.
  final bool mengunggahFoto;

  final bool starting;
  final bool izinDitolak;
  final String? message;

  bool get isRecording => tripId != null;

  RecordingState copyWith({
    String? tripId,
    String? title,
    int? recordedCount,
    ({double lat, double lng, DateTime at})? latest,
    List<({double lat, double lng})>? jejak,
    double? jarakM,
    List<JejakLama>? jejakLama,
    RingkasTrip? menapakTilas,
    bool? mengunggahFoto,
    bool? starting,
    bool? izinDitolak,
    String? message,
    bool clearTrip = false,
    bool clearMessage = false,
  }) {
    return RecordingState(
      tripId: clearTrip ? null : (tripId ?? this.tripId),
      title: clearTrip ? null : (title ?? this.title),
      recordedCount: clearTrip ? 0 : (recordedCount ?? this.recordedCount),
      latest: clearTrip ? null : (latest ?? this.latest),
      jejak: clearTrip ? const [] : (jejak ?? this.jejak),
      jarakM: clearTrip ? 0 : (jarakM ?? this.jarakM),
      jejakLama: clearTrip ? const [] : (jejakLama ?? this.jejakLama),
      menapakTilas: clearTrip ? null : (menapakTilas ?? this.menapakTilas),
      mengunggahFoto: mengunggahFoto ?? this.mengunggahFoto,
      starting: starting ?? this.starting,
      izinDitolak: izinDitolak ?? this.izinDitolak,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Perekam perjalanan.
///
/// Tiga hal yang dijaga di sini:
///
/// 1. **Baterai.** Aliran lokasi disaring oleh jarak, bukan hanya waktu —
///    berdiam di warung kopi tidak menghasilkan ratusan titik kembar. Yang
///    dipakai adalah stream milik sistem, bukan timer yang membangunkan GPS
///    sendiri setiap beberapa detik.
///
/// 2. **Jejak tidak boleh hilang.** Setiap titik ditulis ke database lokal
///    lebih dulu, baru dicoba dikirim. Sinyal putus bukan alasan kehilangan
///    cerita.
///
/// 3. **Peta tidak digambar ulang.** State ini hanya menyimpan posisi terakhir,
///    sehingga halaman peta bisa menambahkan satu titik ke garis yang sudah ada
///    alih-alih membangun ulang seluruh rute tiap 30 detik.
class RecordingController extends Notifier<RecordingState> {
  StreamSubscription<Position>? _positionSub;
  Timer? _syncTimer;
  final _uuid = const Uuid();

  @override
  RecordingState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _syncTimer?.cancel();
    });
    return const RecordingState();
  }

  /// Mulai perjalanan baru dan langsung merekam.
  Future<void> start({
    required String title,
    TripMode mode = TripMode.solo,
    Trip? tapakTilas,
  }) async {
    if (state.isRecording || state.starting) return;
    state = state.copyWith(starting: true, clearMessage: true);

    if (!await _ensureLocationPermission()) {
      state = state.copyWith(
        starting: false,
        izinDitolak: true,
        message:
            'Napak butuh izin lokasi untuk bisa merekam jejakmu. '
            'Tanpa itu, tidak ada yang bisa disimpan.',
      );
      return;
    }

    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.create(
        title: title,
        mode: mode,
        retraceOf: tapakTilas?.id,
      );

      // Jejak lama diambil dan dihitung sekali di sini, bukan berulang tiap
      // titik GPS masuk.
      var lama = const <JejakLama>[];
      if (tapakTilas != null) {
        try {
          lama = siapkanJejakLama(await repo.points(tapakTilas.id));
        } catch (_) {
          // Gagal mengambil rute lama tidak boleh menggagalkan perekaman.
          // Perjalanannya tetap jalan, cuma tanpa perbandingan.
        }
      }

      state = state.copyWith(
        tripId: trip.id,
        title: trip.title,
        recordedCount: 0,
        starting: false,
        jejakLama: lama,
        menapakTilas: tapakTilas == null
            ? null
            : RingkasTrip(
                id: tapakTilas.id,
                title: tapakTilas.title,
                startedAt: tapakTilas.startedAt,
              ),
      );
      _listenToPosition(trip.id);
      _startPeriodicSync();
    } catch (error) {
      state = state.copyWith(starting: false, message: error.toString());
    }
  }

  /// Lanjutkan merekam perjalanan yang belum ditutup.
  Future<void> resume(Trip trip) async {
    if (state.isRecording) return;
    if (!await _ensureLocationPermission()) {
      state = state.copyWith(izinDitolak: true);
      return;
    }
    state = state.copyWith(tripId: trip.id, title: trip.title);
    _listenToPosition(trip.id);
    _startPeriodicSync();
  }

  /// Tutup perjalanan. Sisa antrean dikirim dulu supaya tidak ada yang
  /// tertinggal di perangkat.
  Future<void> stop() async {
    final tripId = state.tripId;
    if (tripId == null) return;

    await _positionSub?.cancel();
    _positionSub = null;
    _syncTimer?.cancel();
    _syncTimer = null;

    await ref.read(syncServiceProvider).flush();

    try {
      await ref.read(tripRepositoryProvider).finish(tripId);
    } catch (_) {
      // Penutupan bisa menyusul saat jaringan pulih; yang penting
      // perekamannya sudah berhenti dan jejaknya aman.
    }

    state = const RecordingState(
      message: 'Perjalanan ditutup. Jejakmu tersimpan.',
    );
    ref.invalidate(tripListProvider);
  }

  /// Tandai singgahan di posisi sekarang — catatan, foto, atau dua-duanya.
  ///
  /// Fotonya diunggah lebih dulu, dan kalau gagal, catatannya tetap disimpan.
  /// Kehilangan sinyal di pinggir jalan tidak boleh berarti kehilangan
  /// kalimat yang sudah terlanjur diketik.
  Future<void> addNote(String note, {XFile? foto}) async {
    final tripId = state.tripId;
    if (tripId == null) return;
    if (note.trim().isEmpty && foto == null) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String? kunciFoto;
    if (foto != null) {
      state = state.copyWith(mengunggahFoto: true, clearMessage: true);
      try {
        kunciFoto = await ref
            .read(photoUploaderProvider)
            .unggah(tripId, foto);
      } catch (error) {
        state = state.copyWith(message: error.toString());
      } finally {
        state = state.copyWith(mengunggahFoto: false);
      }
    }

    await _record(
      tripId,
      position,
      note: note.trim().isEmpty ? null : note.trim(),
      photoUrl: kunciFoto,
    );
  }

  void _listenToPosition(String tripId) {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(
      (position) => _record(tripId, position),
      onError: (Object error) {
        state = state.copyWith(
          message: 'Sinyal lokasi sedang sulit. Napak tetap menunggu.',
        );
      },
    );
  }

  /// Penyaring jarak inilah yang membuat perekaman tidak menguras baterai:
  /// sistem operasi sendiri yang menahan pembaruan sampai benar-benar berpindah.
  LocationSettings _locationSettings() {
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: NapakConfig.minimumDistanceMeters,
    );
  }

  Future<void> _record(
    String tripId,
    Position position, {
    String? note,
    String? photoUrl,
  }) async {
    final recordedAt = position.timestamp.toLocal();

    await ref
        .read(syncServiceProvider)
        .enqueue(
          tripId: tripId,
          clientId: _uuid.v4(),
          lat: position.latitude,
          lng: position.longitude,
          recordedAt: recordedAt,
          alt: position.altitude,
          accuracy: position.accuracy,
          speedMps: position.speed >= 0 ? position.speed : null,
          transportMode: _guessTransportMode(position.speed).wire,
          note: note,
          photoUrl: photoUrl,
        );

    final sebelumnya = state.jejak.isEmpty ? null : state.jejak.last;
    final tambahan = sebelumnya == null
        ? 0.0
        : _jarakMeter(
            sebelumnya.lat,
            sebelumnya.lng,
            position.latitude,
            position.longitude,
          );

    state = state.copyWith(
      recordedCount: state.recordedCount + 1,
      jarakM: state.jarakM + tambahan,
      latest: (
        lat: position.latitude,
        lng: position.longitude,
        at: recordedAt,
      ),
      jejak: [
        ...state.jejak,
        (lat: position.latitude, lng: position.longitude),
      ],
    );
  }

  /// Haversine, dipakai menghitung jarak tempuh sesi berjalan.
  static double _jarakMeter(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    double rad(double d) => d * math.pi / 180;

    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return 2 * 6371008.8 * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Tebakan kasar moda perjalanan dari kecepatan.
  ///
  /// Sengaja kasar. Napak lebih baik mengaku "belum jelas" daripada memberi
  /// label yang salah pada perjalanan seseorang.
  TransportMode _guessTransportMode(double speedMps) {
    if (speedMps < 0) return TransportMode.tidakDiketahui;
    if (speedMps < 2.5) return TransportMode.jalanKaki;
    if (speedMps < 33) return TransportMode.motor;
    if (speedMps < 75) return TransportMode.kereta;
    return TransportMode.pesawat;
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(
      NapakConfig.trackingInterval,
      (_) => ref.read(syncServiceProvider).flush(),
    );
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );

/// Daftar perjalanan milik pengguna.
final tripListProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).list(),
);

/// Perjalanan di tanggal yang sama, tahun-tahun lalu.
final kenanganProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).kenanganHariIni(),
);
