import 'package:flutter_test/flutter_test.dart';
import 'package:napak/features/peta/data/layanan_data.dart';

void main() {
  group('arah', () {
    test('delapan arah mata angin', () {
      expect(namaArah(0), 'utara');
      expect(namaArah(44), 'timur laut');
      expect(namaArah(90), 'timur');
      expect(namaArah(180), 'selatan');
      expect(namaArah(270), 'barat');
      expect(namaArah(337.4), 'barat laut');
      // Hampir 360 kembali ke utara, bukan jatuh ke luar daftar.
      expect(namaArah(359.9), 'utara');
    });

    test('arah dari Jakarta ke Bandung kira-kira tenggara', () {
      final a = arahDerajat(-6.2, 106.82, -6.91, 107.61);
      expect(namaArah(a), 'tenggara');
    });
  });

  group('jarak', () {
    test('Jakarta–Bandung sekitar 118 km garis lurus', () {
      final m = jarakMeter(-6.2, 106.82, -6.91, 107.61);
      expect(m, inInclusiveRange(115000, 122000));
    });

    test('ditulis seperti orang menyebutnya', () {
      expect(teksJarak(430), '430 m');
      expect(teksJarak(2400), '2,4 km');
      expect(teksJarak(18400), '18 km');
    });
  });

  group('layanan offline', () {
    test('posisi pencari mengisi jarak dan arah', () {
      const spbu = Layanan(
        id: 'n1',
        jenis: JenisLayanan.spbu,
        nama: 'SPBU Pertamina',
        lat: -7.9,
        lng: 112.95,
        untukMotor: true,
        untukMobil: true,
      );
      final dari = spbu.dariPosisi(-7.95, 112.95);
      expect(dari.jarakM, inInclusiveRange(5400, 5700));
      expect(namaArah(dari.arah!), 'utara');
    });
  });
}
