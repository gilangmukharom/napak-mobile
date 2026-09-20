import 'package:flutter_test/flutter_test.dart';
import 'package:napak/features/trips/data/trip_models.dart';

void main() {
  _modelBaru();

  group('TripVisibility', () {
    test('nilai tak dikenal jatuh ke private, bukan ke publik', () {
      // Kalau backend suatu saat mengirim nilai baru yang belum dikenal versi
      // aplikasi ini, kegagalannya harus condong ke arah yang aman.
      expect(TripVisibility.fromWire('entah_apa'), TripVisibility.private);
    });

    test('label ditulis dalam Bahasa Indonesia', () {
      expect(TripVisibility.private.label, 'Hanya kamu');
      expect(TripVisibility.public.label, 'Terbuka untuk semua');
    });
  });

  group('TripPoint', () {
    test('menandai koordinat kasar yang dikirim untuk penonton luar', () {
      final titik = TripPoint.fromJson({
        'id': 'abc',
        'lat': -6.175,
        'lng': 106.827,
        'recordedAt': '2026-09-20T01:00:00.000Z',
        'transportMode': 'motor',
        'coarse': true,
        'note': null,
      });

      expect(titik.coarse, isTrue);
      expect(titik.note, isNull);
      expect(titik.transportMode, TransportMode.motor);
    });

    test('moda perjalanan asing tidak ditebak-tebak', () {
      final titik = TripPoint.fromJson({
        'id': 'abc',
        'lat': 0.0,
        'lng': 0.0,
        'recordedAt': '2026-09-20T01:00:00.000Z',
        'transportMode': 'becak',
        'coarse': false,
      });

      expect(titik.transportMode, TransportMode.tidakDiketahui);
    });
  });
}

/// Model yang datang dari server. Yang diuji di sini adalah perilaku saat
/// datanya tidak seperti yang diharapkan — karena versi aplikasi yang beredar
/// di HP orang selalu tertinggal dari versi backend.
void _modelBaru() {
  group('RenderJob', () {
    test('status tak dikenal dianggap masih menunggu, bukan selesai', () {
      final job = RenderJob.fromJson({
        'id': 'r1',
        'status': 'entah_apa',
        'format': 'tegak',
        'template': 'mudik',
        'progress': 40,
        'siapDiunduh': false,
      });

      expect(job.status, StatusRender.menunggu);
      expect(job.sedangBerjalan, isTrue);
    });

    test('hanya dianggap siap kalau server bilang begitu', () {
      final selesai = RenderJob.fromJson({
        'id': 'r2',
        'status': 'selesai',
        'format': 'lebar',
        'template': 'perjalanan',
        'progress': 100,
        'siapDiunduh': true,
        'ukuranByte': 128646,
      });

      expect(selesai.sedangBerjalan, isFalse);
      expect(selesai.siapDiunduh, isTrue);
      expect(selesai.ukuranByte, 128646);
    });

    test('render gagal membawa pesannya', () {
      final gagal = RenderJob.fromJson({
        'id': 'r3',
        'status': 'gagal',
        'format': 'tegak',
        'template': 'perjalanan',
        'progress': 20,
        'siapDiunduh': false,
        'pesanGalat': 'Perjalanan ini belum punya cukup jejak.',
      });

      expect(gagal.status, StatusRender.gagal);
      expect(gagal.pesanGalat, contains('belum punya cukup jejak'));
    });
  });

  group('Recap', () {
    test('membaca nama kota, bukan cuma jumlahnya', () {
      final recap = Recap.fromJson({
        'year': 2026,
        'totalDistanceKm': 494.56,
        'totalTrips': 1,
        'totalCities': 3,
        'cities': ['Cirebon', 'Semarang', 'Surakarta'],
        'caption': 'Satu perjalanan di 2026.',
        'longestTrip': {
          'id': 't1',
          'title': 'Mudik ke Solo',
          'distanceKm': 494.56,
        },
      });

      expect(recap.cities, ['Cirebon', 'Semarang', 'Surakarta']);
      expect(recap.longestTripTitle, 'Mudik ke Solo');
    });

    test('tahan terhadap recap lama yang belum punya daftar kota', () {
      final recap = Recap.fromJson({
        'year': 2025,
        'totalDistanceKm': 0,
        'totalTrips': 0,
        'totalCities': 0,
        'caption': 'Belum ada jejak di 2025.',
      });

      expect(recap.cities, isEmpty);
      expect(recap.longestTripTitle, isNull);
    });
  });

  group('PosisiLangsung', () {
    test('membaca posisi teman seperjalanan dari WebSocket', () {
      final posisi = PosisiLangsung.fromJson({
        'tripId': 't1',
        'userId': 'u2',
        'name': 'Rizky',
        'lat': -7.95,
        'lng': 112.96,
        'at': '2026-09-20T02:05:00.000Z',
      });

      expect(posisi.nama, 'Rizky');
      expect(posisi.lat, -7.95);
    });

    test('memberi nama sapaan kalau servernya tidak mengirim nama', () {
      final posisi = PosisiLangsung.fromJson({
        'userId': 'u3',
        'lat': 0.0,
        'lng': 0.0,
        'at': '2026-09-20T02:05:00.000Z',
      });

      expect(posisi.nama, 'Penjejak');
    });
  });

  group('TripPoint.recordedBy', () {
    test('dipakai memecah jejak per orang di peta Trip Bareng', () {
      final titik = TripPoint.fromJson({
        'id': 'p1',
        'lat': -7.96,
        'lng': 112.63,
        'recordedAt': '2026-09-20T01:00:00.000Z',
        'transportMode': 'motor',
        'coarse': false,
        'recordedBy': 'u2',
      });

      expect(titik.recordedBy, 'u2');
    });

    test('tidak meledak kalau servernya belum mengirim perekamnya', () {
      final titik = TripPoint.fromJson({
        'id': 'p2',
        'lat': 0.0,
        'lng': 0.0,
        'recordedAt': '2026-09-20T01:00:00.000Z',
        'transportMode': 'motor',
        'coarse': true,
      });

      expect(titik.recordedBy, '');
    });
  });
}
