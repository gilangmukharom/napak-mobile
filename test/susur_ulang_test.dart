import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/features/recording/application/susur_ulang.dart';
import 'package:tourvella/features/trips/data/trip_models.dart';

/// Perjalanan lama: lurus ke timur, 10 km tiap 30 menit.
List<TripPoint> _perjalananLama() {
  final berangkat = DateTime(2025, 3, 28, 5);
  return [
    for (var i = 0; i < 7; i++)
      TripPoint(
        id: 'p$i',
        lat: -6.2,
        // ~0,0899 derajat bujur ≈ 10 km di khatulistiwa.
        lng: 106.8 + i * 0.0899,
        recordedAt: berangkat.add(Duration(minutes: i * 30)),
        transportMode: TransportMode.mobil,
        coarse: false,
        recordedBy: 'u1',
        note: i == 3 ? 'Berhenti makan soto' : null,
      ),
  ];
}

void main() {
  group('siapkanJejakLama', () {
    test('menghitung jarak dan waktu kumulatif dari titik berangkat', () {
      final lama = siapkanJejakLama(_perjalananLama());

      expect(lama.first.jarakTempuhM, 0);
      expect(lama.first.sejakBerangkat, Duration.zero);

      expect(lama[1].jarakTempuhM / 1000, closeTo(10, 0.5));
      expect(lama[1].sejakBerangkat, const Duration(minutes: 30));

      expect(lama.last.jarakTempuhM / 1000, closeTo(60, 2));
      expect(lama.last.sejakBerangkat, const Duration(minutes: 180));
    });

    test('perjalanan kosong tidak bikin rusak', () {
      expect(siapkanJejakLama([]), isEmpty);
    });
  });

  group('bandingkan', () {
    final lama = siapkanJejakLama(_perjalananLama());

    test(
      'tahu kamu lebih cepat saat menempuh jarak yang sama lebih singkat',
      () {
        // Dulu 20 km butuh 60 menit; sekarang baru 45 menit.
        final hasil = bandingkan(
          lama: lama,
          sudahBerjalan: const Duration(minutes: 45),
          jarakSekarangM: 20000,
        );

        expect(hasil.selisih, isNotNull);
        expect(hasil.selisih!.inMinutes, closeTo(15, 2));
        expect(kalimatSelisih(hasil.selisih), contains('lebih cepat'));
      },
    );

    test('tahu kamu lebih lambat', () {
      // Dulu 20 km butuh 60 menit; sekarang sudah 90 menit.
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 90),
        jarakSekarangM: 20000,
      );

      expect(hasil.selisih!.inMinutes, closeTo(-30, 2));
      expect(kalimatSelisih(hasil.selisih), contains('lebih lambat'));
    });

    test('berhenti lama tidak dihitung sebagai tertinggal', () {
      // Inti dari membandingkan lewat jarak, bukan waktu. Orang yang berhenti
      // makan satu jam lalu jalan lagi dengan kecepatan sama semestinya tidak
      // dibilang "tertinggal jauh" — dia cuma berhenti.
      //
      // Dulu 30 km butuh 90 menit. Sekarang 30 km dalam 92 menit, padahal
      // separuhnya dipakai berhenti: tetap terbaca hampir sama.
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 92),
        jarakSekarangM: 30000,
      );

      expect(hasil.selisih!.inMinutes.abs(), lessThan(5));
      expect(kalimatSelisih(hasil.selisih), 'Persis seperti dulu.');
    });

    test('menunjukkan di mana kamu berada dulu pada waktu yang sama', () {
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 60),
        jarakSekarangM: 15000,
      );

      // Pada menit ke-60 dulu, kamu sudah 20 km dari titik berangkat.
      expect(hasil.jarakDuluM / 1000, closeTo(20, 1));
      expect(hasil.posisiDulu, isNotNull);
      expect(hasil.posisiDulu!.lng, closeTo(106.9798, 0.01));
    });

    test('menyebut catatan lama saat kamu lewat tempat yang sama', () {
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 90),
        jarakSekarangM: 30000,
        // Persis di titik keempat, tempat dulu berhenti makan soto.
        posisiSekarang: (lat: -6.2, lng: 106.8 + 3 * 0.0899),
      );

      expect(hasil.catatanTerdekat, 'Berhenti makan soto');
    });

    test('tidak mengarang catatan saat kamu jauh dari mana pun', () {
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 90),
        jarakSekarangM: 30000,
        posisiSekarang: (lat: -7.5, lng: 110.8),
      );

      expect(hasil.catatanTerdekat, isNull);
    });

    test('berhenti membandingkan saat kamu sudah melewati rute lama', () {
      // Sudah lebih jauh daripada seluruh perjalanan dulu. Tidak ada lagi
      // yang bisa dibandingkan dengan jujur.
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: const Duration(minutes: 200),
        jarakSekarangM: 90000,
      );

      expect(hasil.selisih, isNull);
      expect(kalimatSelisih(hasil.selisih), 'Baru berangkat.');
    });

    test('tidak membandingkan apa-apa di detik pertama', () {
      final hasil = bandingkan(
        lama: lama,
        sudahBerjalan: Duration.zero,
        jarakSekarangM: 0,
      );

      expect(hasil.selisih, isNull);
    });

    test('tanpa perjalanan lama, semuanya kosong tanpa meledak', () {
      final hasil = bandingkan(
        lama: const [],
        sudahBerjalan: const Duration(minutes: 30),
        jarakSekarangM: 10000,
      );

      expect(hasil.posisiDulu, isNull);
      expect(hasil.selisih, isNull);
    });
  });

  group('kalimatSelisih', () {
    test('tidak mengarang ketelitian di bawah dua menit', () {
      // Simpangan GPS sendiri sudah sebesar itu.
      expect(
        kalimatSelisih(const Duration(seconds: 40)),
        'Persis seperti dulu.',
      );
      expect(
        kalimatSelisih(const Duration(seconds: -70)),
        'Persis seperti dulu.',
      );
    });

    test('beralih ke jam saat selisihnya besar', () {
      expect(kalimatSelisih(const Duration(minutes: 95)), contains('jam'));
      expect(kalimatSelisih(const Duration(minutes: 95)), contains('cepat'));
    });
  });
}
