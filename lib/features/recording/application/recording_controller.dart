import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/napak_config.dart';
import '../../../core/providers.dart';
import '../../trips/data/trip_models.dart';
import 'sync_service.dart';

@immutable
class RecordingState {
  const RecordingState({
    this.tripId,
    this.title,
    this.recordedCount = 0,
    this.latest,
    this.jejak = const [],
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
      final trip = await ref
          .read(tripRepositoryProvider)
          .create(title: title, mode: mode);
      state = state.copyWith(
        tripId: trip.id,
        title: trip.title,
        recordedCount: 0,
        starting: false,
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

  /// Tambah catatan pada posisi saat ini — "di sini kami berhenti makan soto".
  Future<void> addNote(String note) async {
    final tripId = state.tripId;
    if (tripId == null || note.trim().isEmpty) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    await _record(tripId, position, note: note.trim());
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

  Future<void> _record(String tripId, Position position, {String? note}) async {
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
        );

    state = state.copyWith(
      recordedCount: state.recordedCount + 1,
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
