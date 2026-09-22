import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/features/garasi/data/garasi_data.dart';
import 'package:tourvella/features/linimasa/data/linimasa_data.dart';

void main() {
  group('PostLinimasa', () {
    Map<String, dynamic> contoh() => {
      'tripId': 't1',
      'judul': 'Mudik ke Tangerang',
      'mode': 'solo',
      'mulai': '2026-04-01T01:00:00.000Z',
      'selesai': '2026-04-01T08:00:00.000Z',
      'km': 255.3,
      'penulis': {'id': 'u1', 'nama': 'Gilang', 'fotoUrl': null},
      'milikSendiri': false,
      'dari': 'Cirebon',
      'ke': 'Tangerang',
      'media': [
        {'url': 'https://s3/a.jpg', 'video': false},
        {'url': 'https://s3/b.jpg', 'video': true},
      ],
      // GeoJSON: [lng, lat].
      'previewPath': [
        [108.55, -6.73],
        [106.63, -6.18],
      ],
      'kendaraan': {'nama': 'Si Merah', 'jenis': 'motor'},
      'salut': 3,
      'sudahSalut': true,
    };

    test('membaca [lng, lat], bukan sebaliknya', () {
      final p = PostLinimasa.fromJson(contoh());
      // Tertukar sedikit saja, Cirebon tergambar di Samudra Hindia.
      expect(p.previewPath.first.lat, -6.73);
      expect(p.previewPath.first.lng, 108.55);
    });

    test('membawa kendaraan, media, dan salut', () {
      final p = PostLinimasa.fromJson(contoh());
      expect(p.kendaraanNama, 'Si Merah');
      expect(p.kendaraanJenis, JenisKendaraan.motor);
      expect(p.media, hasLength(2));
      expect(p.media.last.video, isTrue);
      expect(p.salut, 3);
      expect(p.sudahSalut, isTrue);
    });

    test('perjalanan tanpa kendaraan dan tanpa foto tetap terbaca', () {
      final j = contoh()
        ..['kendaraan'] = null
        ..['media'] = <dynamic>[]
        ..['dari'] = null;
      final p = PostLinimasa.fromJson(j);
      expect(p.kendaraanNama, isNull);
      expect(p.media, isEmpty);
      expect(p.dari, isNull);
    });

    test('memberi salut hanya mengubah salutnya', () {
      final p = PostLinimasa.fromJson(contoh()).denganSalut(4, false);
      expect(p.salut, 4);
      expect(p.sudahSalut, isFalse);
      expect(p.judul, 'Mudik ke Tangerang');
    });
  });

  group('Kendaraan', () {
    test('jenis asing tidak ditebak-tebak jadi motor', () {
      final k = Kendaraan.fromJson({
        'id': 'k1',
        'nama': 'Odong',
        'jenis': 'odong_odong',
        'km': 12,
        'perjalanan': 1,
        'milikSendiri': true,
      });
      expect(k.jenis, JenisKendaraan.lainnya);
      expect(k.km, 12.0);
    });
  });
}
