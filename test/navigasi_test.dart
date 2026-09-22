import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/features/navigasi/application/penjejak_rute.dart';
import 'package:tourvella/features/navigasi/application/ucapan_navigasi.dart';
import 'package:tourvella/features/navigasi/data/navigasi_data.dart';

/// Rute lurus ke timur sepanjang ±1,1 km dengan satu belokan di tengah.
Rute ruteUji() {
  const awal = (lat: -7.8000, lng: 110.3600);
  final garis = [
    for (var i = 0; i <= 10; i++)
      (lat: awal.lat, lng: awal.lng + i * 0.001), // ±111 m per langkah
  ];

  return Rute(
    jarakM: 1110,
    durasiDetik: 180,
    garis: garis,
    langkah: [
      const LangkahRute(
        jarakM: 555,
        durasiDetik: 90,
        jenis: 'berangkat',
        arah: 'lurus',
        jalan: 'Jalan Solo',
        lat: -7.8000,
        lng: 110.3600,
      ),
      const LangkahRute(
        jarakM: 555,
        durasiDetik: 60,
        jenis: 'belok',
        arah: 'kanan',
        jalan: 'Jalan Kaliurang',
        lat: -7.8000,
        lng: 110.3650, // di tengah rute
      ),
      const LangkahRute(
        jarakM: 0,
        durasiDetik: 0,
        jenis: 'sampai',
        arah: 'lurus',
        lat: -7.8000,
        lng: 110.3700,
      ),
    ],
    ringkasan: 'Rute ke Yogyakarta sudah siap.',
    tujuan: const Tujuan(
      nama: 'Yogyakarta',
      provinsi: 'DI Yogyakarta',
      lat: -7.8000,
      lng: 110.3700,
    ),
  );
}

void main() {
  group('penjejak rute', () {
    final penjejak = PenjejakRute(ruteUji());

    test('panjang rute dihitung menyusuri garis', () {
      expect(penjejak.panjangM, closeTo(1103, 20));
    });

    test('di awal, manuver berikutnya adalah belokan di tengah', () {
      final k = penjejak.perbarui(-7.8000, 110.3600);
      expect(k.indeksLangkah, 1);
      expect(k.jarakKeManuverM, closeTo(551, 20));
      expect(k.sampai, isFalse);
    });

    test('mendekati belokan, jaraknya menyusut', () {
      final k = penjejak.perbarui(-7.8000, 110.3646, dariLangkah: 1);
      expect(k.indeksLangkah, 1);
      expect(k.jarakKeManuverM, closeTo(44, 15));
    });

    test('setelah melewati belokan, pindah ke langkah berikutnya', () {
      final k = penjejak.perbarui(-7.8000, 110.3660, dariLangkah: 1);
      expect(k.indeksLangkah, 2);
    });

    test('jarak diukur menyusuri rute, bukan garis lurus', () {
      // Rute berbentuk L: lurus ke timur 1 km, lalu ke utara 1 km. Garis
      // lurus dari awal ke ujung cuma ±1,4 km; menyusuri rute 2 km.
      final belok = Rute(
        jarakM: 2000,
        durasiDetik: 300,
        garis: [
          (lat: -7.8, lng: 110.36),
          (lat: -7.8, lng: 110.369),
          (lat: -7.791, lng: 110.369),
        ],
        langkah: const [
          LangkahRute(
            jarakM: 2000,
            durasiDetik: 300,
            jenis: 'sampai',
            arah: 'lurus',
            lat: -7.791,
            lng: 110.369,
          ),
        ],
        ringkasan: '',
        tujuan: const Tujuan.titik(-7.791, 110.369),
      );

      final k = PenjejakRute(belok).perbarui(-7.8, 110.36);
      final lurus = jarakMeter(
        (lat: -7.8, lng: 110.36),
        (lat: -7.791, lng: 110.369),
      );
      expect(lurus, closeTo(1400, 120));
      expect(k.jarakKeManuverM, closeTo(1990, 120));
    });

    test('keluar jalur terdeteksi dari jarak ke garis rute', () {
      final diJalur = penjejak.perbarui(-7.8001, 110.3620);
      expect(diJalur.jarakDariRuteM, lessThan(ambangKeluarJalurM));

      // ±400 m di utara rute.
      final minggat = penjejak.perbarui(-7.7964, 110.3620);
      expect(minggat.jarakDariRuteM, greaterThan(ambangKeluarJalurM));
    });

    test('sampai di tujuan saat sisa rutenya habis', () {
      final k = penjejak.perbarui(-7.8000, 110.36995, dariLangkah: 2);
      expect(k.sampai, isTrue);
    });
  });

  group('ambang suara', () {
    test('mengumumkan sekali per ambang, dari jauh ke dekat', () {
      final sudah = <double>{};
      expect(ambangBaru(1200, sudah), isNull); // belum sampai 1 km
      expect(ambangBaru(900, sudah), 1000);
      sudah.add(1000);
      expect(ambangBaru(800, sudah), isNull);
      expect(ambangBaru(350, sudah), 400);
      sudah.add(400);
      expect(ambangBaru(100, sudah), 120);
      sudah.add(120);
      expect(ambangBaru(10, sudah), 25);
    });

    test('belokan pendek tidak diumumkan "1 kilometer lagi"', () {
      final sudah = <double>{};
      // Manuvernya cuma 300 m dari manuver sebelumnya: ambang 1 km dan 400 m
      // dilewati diam-diam, dan pada 280 m memang belum waktunya bersuara.
      expect(ambangBaru(280, sudah, jarakLangkah: 300), isNull);
      expect(sudah, containsAll([1000.0, 400.0]));
      // Baru saat benar-benar dekat.
      expect(ambangBaru(100, sudah, jarakLangkah: 300), 120);
    });
  });

  group('kalimat navigasi di HP', () {
    const belokKanan = LangkahRute(
      jarakM: 500,
      durasiDetik: 60,
      jenis: 'belok',
      arah: 'kanan',
      jalan: 'Jalan Kaliurang',
      lat: 0,
      lng: 0,
    );

    test('jarak dulu, lalu tindakan — nama jalan tidak ikut dikecilkan', () {
      expect(
        kalimatNavigasi(belokKanan, 300),
        '300 meter lagi, belok kanan ke Jalan Kaliurang',
      );
      expect(
        kalimatNavigasi(belokKanan, 12),
        'Belok kanan ke Jalan Kaliurang sekarang',
      );
    });

    test('jarak diucapkan seperti orang', () {
      expect(jarakDiucapkan(847), '850 meter lagi');
      expect(jarakDiucapkan(1234), '1,2 kilometer lagi');
      expect(jarakSingkat(1234), '1,2 km');
      expect(jarakSingkat(347), '350 m');
    });

    test('nama jalan kepanjangan dibuang, bukan dibacakan utuh', () {
      const panjang = LangkahRute(
        jarakM: 100,
        durasiDetik: 20,
        jenis: 'belok',
        arah: 'kiri',
        jalan: 'Jalan Kolektor Sekunder Lingkar Utara Blok C Kavling 12',
        lat: 0,
        lng: 0,
      );
      expect(kalimatManuver(panjang), 'Belok kiri');
    });
  });
}
